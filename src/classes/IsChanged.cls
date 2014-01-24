public class IsChanged implements Process.Plugin {
    
    private static Integer truncateSize = 32768;
    
    public class Eda {
        public SObject configurable = IsChangedConfiguration__c.SObjectType.newSObject();
        public String icon = 'application_side_expand';
    }
    
    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
        plugin.Name = 'IsChanged';
        plugin.Description = 'Detects if the value of a field has changed on an incoming SObject since the last time';
        plugin.Tag = 'Event Driven Architecture';
        
        
        plugin.OutputParameters = new List<Process.PluginDescribeResult.OutputParameter>{
            new Process.PluginDescribeResult.OutputParameter(
                'newId',
                'The id that points to an object representing the current state of a changed topic.',
                Process.PluginDescribeResult.ParameterType.ID
            ),
            new Process.PluginDescribeResult.OutputParameter(
                'oldId',
                'The id that points to an object representing the prior state of a changed topic.',
                Process.PluginDescribeResult.ParameterType.ID
            ),
            new Process.PluginDescribeResult.OutputParameter(
                'newValue',
                'The value representing the current state of a changed topic. (Note: depending on the schema type of the ' +
                'source field of a changed topic, this value MAY be base64 encoded and WILL be truncated at' + truncateSize  + ' bytes). ',
                Process.PluginDescribeResult.ParameterType.STRING
            ),
            new Process.PluginDescribeResult.OutputParameter(
                'oldValue',
                'The value represnting the prior state of a changed topic. (Note: depending on the schema type of the ' +
                'source field of a changed topic, this value MAY be base64 encoded and WILL be truncated at' + truncateSize + ' bytes). ',
                Process.PluginDescribeResult.ParameterType.STRING
            )           
                
                
        };

        return plugin;
    }
    
    public Process.PluginResult invoke(Process.PluginRequest pluginRequest) {
        Map<String,Object> notification = pluginRequest.inputParameters;
        List<Map<String,Object>> notifications = new List<Map<String,Object>>();
        
        // retrieve state
        IsChangedConfiguration__c configuration = [
            SELECT Id, NewHash__c, OldHash__c, NewId__c, OldId__c, NewValue__c, OldValue__c, FieldName__c
            FROM IsChangedConfiguration__c
            WHERE Id = :(Id)notification.get('eda__configuration')
        ];
  
        // retrieve current value of object referenced by 'id'
        // on notification
        Id objectId = (Id)notification.get('id');    
        SObjectType objectType = objectId.getSObjectType();
        String objectName = objectType.getDescribe().getName();
        String fieldName = configuration.FieldName__c; 
        String query = 'SELECT ' + fieldName + ' FROM ' + objectName + ' WHERE Id = :objectId';
        SObject obj = Database.query(query);
        
        
        // derive the following 'new' attributes : 
        //  - the new hash value (the hash on the current value  ) 
        //  - the new value  ( either it's the  current value  or it's the base64 encoded version of the current value but 
        //    in either case we truncte to the maximum large text field size defined in the static : 'truncateSize'
        Blob newValueAsBlob = Blob.valueOf(String.valueOf(obj.get(fieldName)));
        String newHash = EncodingUtil.convertToHex(Crypto.generateDigest('MD5', newValueAsBlob));
        String newValue = getNewValue(obj, fieldName, truncateSize);
        
        // detect a change
        Boolean isChanged = (configuration.NewHash__c != newHash);

        // push the state (new to old)
        configuration.OldId__c = configuration.NewId__c;
        configuration.NewId__c = objectId;     
        configuration.OldValue__c = configuration.NewValue__c;
        configuration.NewValue__c = newValue;
        configuration.OldHash__c = configuration.NewHash__c;
        configuration.NewHash__c = newHash;     
        update configuration;

        // release notification if state has changed
        if  (isChanged) {
            notification.put('oldValue' , configuration.OldValue__c );
            notification.put('newValue' , configuration.NewValue__c );    
            notification.put('oldId' , configuration.OldId__c );
            notification.put('newId' , configuration.NewId__c);            
            notifications.add(notification);
        }

        return Utility.convert(notifications);
    }
    
     @TestVisible
     private static String getNewValue(SObject obj, String fieldName, integer maxValueSize) {
        Boolean isBlobType = getIsBlobType(obj, fieldName);
        String newValue =
            ( isBlobType ) ?
            EncodingUtil.base64Encode( (Blob) obj.get(fieldName) ) : 
             String.valueOf(obj.get(fieldName));
         
        return newValue.left(maxValueSize);
    
    }
    
    @TestVisible
    private static Boolean getIsBlobType(SObject obj, String fieldName) {
        Boolean isBlobType = false;  
        Map<String, Schema.SObjectField> fieldNameToFieldToken = obj.getSObjectType().getDescribe().fields.getMap();
        for ( String key : fieldNameToFieldToken.keySet()) {
            if (key.toLowerCase() == fieldName.toLowerCase()) {     
                Schema.DescribeFieldResult describeFieldResult = (Schema.DescribeFieldResult) fieldNameToFieldToken.get(key).getDescribe();
                Schema.DisplayType displayType = describeFieldResult.getType();
                if (displayType == Schema.DisplayType.BASE64) {
                    isBlobType = true;    
                }
                //TODO :: may need to add more types here 
                // see http://www.salesforce.com/us/developer/docs/dbcom_apex250/Content/apex_methods_system_fields_describe.htm#apex_displaytype
            }
        }
        
        return isBlobType;
    }
}