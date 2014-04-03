public class IsChanged  implements Process.Plugin {
    
    @TestVisible
    private static Integer persistDuration = ( 60*24 ) * 7; // seven days
    
    public class Meta {
        public SObject ConfigObject = IsChangedConfiguration__c.SObjectType.newSObject();
        public String Icon = 'application_side_expand';
        public String DocsPageUrl = Page.IsChangedConfigurationHelp.getUrl();
    }
    
    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
        plugin.Name = 'IsChanged';
        plugin.Description = 'Detects if the value of a field has changed on an incoming SObject since the last time';
        plugin.Tag = 'Sample Processes';

        plugin.OutputParameters = new List<Process.PluginDescribeResult.OutputParameter>{
            new Process.PluginDescribeResult.OutputParameter(
                'newBlobId',
                'The id that points to a a blob representation of the current state of a changed topic. ' +
                '(Note: this will be null when newValue is valued ). ',
                Process.PluginDescribeResult.ParameterType.ID
            ),
            new Process.PluginDescribeResult.OutputParameter(
                'oldBlobId',
                'The id that points to a a blob representation of the prior state of a changed topic.' +
                '(Note: this will be null when oldValue is valued ). ',
                Process.PluginDescribeResult.ParameterType.ID
            ),
            new Process.PluginDescribeResult.OutputParameter(
                'newValue',
                'The value representing the current state of a changed topic.' +
                '(Note: this will be null when newBlobId is valued ). ',
                Process.PluginDescribeResult.ParameterType.STRING
            ),
            new Process.PluginDescribeResult.OutputParameter(
                'oldValue',
                'The value represnting the prior state of a changed topic.' +
                '(Note: this will be null when oldBlobId is valued ). ',
                Process.PluginDescribeResult.ParameterType.STRING
            )
                
                
        };

        return plugin;
    }
    
    public Process.PluginResult invoke(Process.PluginRequest pluginRequest) {
        Map<String,Object> parameters = pluginRequest.inputParameters;
        List<Map<String,Object>> parametersList = new List<Map<String,Object>>();
        
        // retrieve state
        IsChangedConfiguration__c configuration = (IsChangedConfiguration__c)SalesforceObject.getById((Id)parameters.get('eda_ConfigObjectId'));
  
        // Is this the first run ?
        Boolean firstRun = (configuration.OldHash__c == null);
        
        // retrieve current value of object referenced by 'Id'
        // on parameters
        SObject obj = SalesforceObject.getById((Id)parameters.get('Id'));

        // derive the following 'new' attributes :
        //  -  if current value is
        //     1. a blob
        //     2. 256 bytes or more
        //     then assign  current value to  newValueAsBlob  , else set newValueAsBlob to null
        //  -  if current value is
        //     1. not a blob
        //     2. and 255 bytes or less
        //     then assign  current value to  newValueAsString  , else set newValueAsString to null
        //  -  assign a hash of the current value to newHash
        Map<string,Object> attributes =  new Map<string,Object> {
            'object' => obj.get(configuration.FieldName__c),
            'configurationId' => configuration.Id,
            'newBlobId' => null,
            'newValueAsString' => null,
            'newHash' => null
        };
        
        deriveNewAttributes(  attributes ) ;
        
        String newHash = (String) attributes.get('newHash');
        String newValueAsString = ( String ) attributes.get('newValueAsString');
        Id newBlobId = ( Id ) attributes.get('newBlobId');
        
        
        // detect a change
        Boolean isChanged =  isChanged(configuration.NewHash__c, newHash,  firstRun);
        
        
        // push the state (new to old)
        configuration.oldBlobId__c = configuration.newBlobId__c;
        configuration.newBlobId__c = newBlobId;
        configuration.OldValue__c = configuration.NewValue__c;
        configuration.NewValue__c = newValueAsString;
        configuration.OldHash__c = configuration.NewHash__c;
        configuration.NewHash__c = newHash;
        update configuration;
        
        // release parameters if state has changed
        if  (isChanged) {
            parameters.put('oldValue' , configuration.OldValue__c );
            parameters.put('newValue' , configuration.NewValue__c );
            parameters.put('oldBlobId' , configuration.oldBlobId__c );
            parameters.put('newBlobId' , configuration.newBlobId__c);
            parametersList.add(parameters);
        }
        
        // housekeeping
        deleteOldAttachments( persistDuration );
        
        return EdaUtility.convert(parametersList);
    }
 
 
    @TestVisible
    private static Boolean isChanged(String lastHash, String latestHash, Boolean firstRun) {
        Boolean isChanged = (lastHash != latestHash);
        if ( firstRun ) {
            isChanged = false;
        }
        
        return isChanged;
    }
    
    @TestVisible
    private static void deriveNewAttributes(Map<string,Object> attributes) {
        Boolean isBlob = ( attributes.get('object') instanceof Blob);
        Blob newValueAsBlob = (  isBlob ) ?  (Blob) attributes.get('object')  :  Blob.valueOf(  (String) attributes.get('object')  );
        String newHash = EncodingUtil.convertToHex(Crypto.generateDigest('MD5', newValueAsBlob));
        String  newValueAsString  = ( ! isBlob ) ?  (String)  attributes.get('object') :  null;
        if ( ! isBlob ) {
            newValueAsBlob = null;
            if ( newValueAsString.length() > 255 ) {
                newValueAsBlob = Blob.valueOf(  newValueAsString  );
                newValueAsString  =  null;
                isBlob = true;
            }
        }
        
        // write away blob
        Id newBlobId = null;
        if (isBlob) {
            Attachment attachment = new Attachment(
                Name = 'IsChanged-' + DateTime.Now().format('YYYY-MM-DD HH:mm:ss').replace(' ','T'),
                Body = newValueAsBlob,
                ParentId = (Id) attributes.get('configurationId')
            );
            insert attachment;
            newBlobId = attachment.Id;
        }
        
        
        attributes.put( 'newBlobId' ,  newBlobId);
        attributes.put( 'newValueAsString', newValueAsString);
        attributes.put( 'newHash', newHash);
    }
    
    @TestVisible
    private static void deleteOldAttachments(Integer persistDurationInMinutes) {
        DateTime stampComparator = System.Now().addMinutes(-1 * persistDurationInMinutes);
        
       // Note : because you cannot update LastModifiedDate or CreateDate in testMethod
       //        we adjust the implementation to the more testable but less efficient
       //        approach
        
       // Most efficient approach
       //List<Attachment> attachments = [
       //    SELECT Id, Name
       //    FROM Attachment
       //    WHERE Name LIKE 'IsChanged-%'
       //        AND LastModifiedDate < :stampComparator
       //] ;
       //List<Id> ids = new List<Id>( ( new Map<Id, Attachment>(attachments)).keySet() );
       
       // More testable approach
       List<Id> ids = new List<Id>();
       List<Attachment> attachments = [
           SELECT Id, Name
           FROM Attachment
           WHERE Name LIKE 'IsChanged-%'
       ] ;
       for (Attachment  attachment : attachments) {
            DateTime lastModifiedDate = (DateTime)Json.deserialize('"' + attachment.Name.substringAfter('-')+ '"', DateTime.class);
            if (lastModifiedDate < stampComparator) {
                ids.add(attachment.Id);
            }
       }

        if (ids.size() > 0) {
            Database.delete(ids);
            Database.emptyRecycleBin(ids);
        }
     }
}