public with sharing class LogInitializer {
    
    public class LogInitializerException extends Exception {}
    
    public class Meta {
        public String Tag = 'Event Driven Architecture';
        public String Name = 'LogInitializer';
        public String Description = 'Creates a grouping identifier which all subsequent LogWriter processes log against.';
        public SObject ConfigObject = LogConfiguration__c.SObjectType.newSobject();
        public String Icon = 'pencil';
        public String DocsPageUrl = Url.getSalesforceBaseUrl().toExternalForm() + Page.LogHelp.getUrl();
        
        public Map<String,String> Outputs = new Map<String,String>{
            'eda_LogGroupIds' => (List<Id>.class).getName() //An identifier that associates instances of steps.
        };
    }
    
    public String Parameters;
    
    override public String toString() {
        if (!SObjectType.LogGroup__c.Createable) throw new Broker.CrudException('!SObjectType.LogGroup__c.Createable');
     
        Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(this.Parameters);
        List<Map<String,Object>> parametersList = new List<Map<String,Object>>();
        
        
        
         //derive the SequenceName and Position
         List<Step__c> steps = [
             SELECT Id, Position__c, Sequence__r.Name
             FROM Step__c
             WHERE Sequence__r.Name = :(String)parameters.get('eda_SequenceName')
             AND Position__c = :(Decimal) parameters.get('eda_Position')
         ];
         if (steps.size() == 0) {
            throw new LogInitializerException('Unable to access the Step Position and Sequence Name');
         }
         Step__c  step = steps[0];
 
        //get group identifier instruction from configuration
        LogConfiguration__c configuration;
        try {
            configuration = (LogConfiguration__c)SalesforceObject.getById((Id)parameters.get('eda_ConfigObjectId'));
        } catch (System.QueryException e) {
            throw new LogInitializerException('Unable to access Log Configuration');
        }
        
         // insert composite key values into log group :
         // the composite key comprises
         // 1.  the date-time stamp
         // 2.  a (fairly unique ) business group value
         Id dataId =  (Id)parameters.get('Id');
         String groupIdentifier = getBusinesGroupIdentifier(configuration, step, dataId) ;
         LogGroup__c logGroup = new LogGroup__c( LogConfiguration__c = configuration.Id,  GroupIdentifier__c = groupIdentifier, Stamp__c = System.Now());
         insert logGroup;

         // update outbound message
         List<Object> logGroupIds = (List<Object>)parameters.get('eda_LogGroupIds');
         if (logGroupIds == null) {
             logGroupIds = new List<Object>();
         }
         logGroupIds.add(logGroup.Id);
         parameters.put('eda_LogGroupIds', logGroupIds);

         
         return Json.serialize(new List<Map<String,Object>>{parameters});
    }

 
    
    @TestVisible private static SObject getHydrated(Id theId) {
        try {
            return SalesforceObject.getById(theId);
        } catch (Exception e) {
            throw new LogInitializerException('Cannot hydate SObject with Id=[' + theId + ']' + e.getStackTraceString());
        }
    }


    @TestVisible private static String getIdentifer(String key, SObject so) {
        return (String) so.get(key);
    }
    
    
    @TestVisible private static String getBusinesGroupIdentifier(LogConfiguration__c configuration, Step__c  step,  Id dataId) {

        //  default :
        //
        //  "sequence name" and "step position"
        //  (always use this if StaticGroupIdentifier__c from configuration equates to null)
        String defaultGroupIdentifier =  step.Sequence__r.Name + '-' + step.Position__c;
        
        
        //  preferred alternatives :
        //
        //     alternative 1  use non-null StaticGroupIdentifier__c from configuration
        //     even better
        //     alternative 2  attempt obtain a user friendly "business id" from the
        //                    object by defining a field of that object in the
        //                    DynamicGroupIdentifier__c field
        //                    if successful, any entry in StaticGroupIdentifier__c is ignored
        
        String groupIdentifier =  configuration.StaticGroupIdentifier__c;
        String dynamicGroupIdentifier =  configuration.DynamicGroupIdentifier__c;
        
        Boolean flagBusinessIdOk = true;
        String businessId;
        if ( !String.isBlank(dynamicGroupIdentifier) ) {
            try {
                businessId = getIdentifer(dynamicGroupIdentifier,   getHydrated(dataId)   );
                if (businessId == null) {
                    flagBusinessIdOk = false;
                }
            } catch (Exception e) {
                flagBusinessIdOk = false; //originally :: swallow / non-intrusive - default acceptable
            }
        }
              
        if ( String.isBlank(groupIdentifier) ) {
            groupIdentifier = defaultGroupIdentifier;
        }
              
        if ( !String.isBlank(businessId) ) {
            groupIdentifier = businessId;
        }

        if (!flagBusinessIdOk) {
            groupIdentifier = 'DYNAMIC-KEY-ON-'+defaultGroupIdentifier+'-NOT-FOUND';  
        }
        
        return groupIdentifier;
    }

}