public with sharing class AuditInitializer {
    
    public String Parameters;
    public AuditInitializerConfig__c StepConfig;
    
    public class ESB {
        public String Tag = 'Enterprise Service Bus';
        public String Name = 'Audit Initializer';
        public String Description = 'Creates a grouping identifier which all subsequent Audit Writer processes audit against.';
        public SObject StepConfig = AuditInitializerConfig__c.SObjectType.newSobject();
        public String Icon = 'pencil';
        public String HelpUrl = Page.AuditInitializerConfigCsh.getUrl();
        
        public Map<String,String> Outputs = new Map<String,String>{
            'esb__AuditGroupIds' => 'LIST<ID> of potentially multiple groups from AuditInitializer steps.'
        };
        
    }
    
    public class AuditInitializerException extends Exception {}
    
    override public String toString() {
        if (!SObjectType.AuditGroup__c.Createable) throw new Broker.CrudException('!SObjectType.AuditGroup__c.Createable');
     
        Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(this.Parameters);
        List<Map<String,Object>> parametersList = new List<Map<String,Object>>();
        
        
        
         //derive the SequenceName and Position
         List<Step__c> steps = [
             SELECT Id, Position__c, Sequence__r.Name
             FROM Step__c
             WHERE Sequence__r.Name = :(String)parameters.get('__SequenceName')
             AND Position__c = :(Decimal) parameters.get('__Position')
         ];
         if (steps.size() == 0) {
            throw new AuditInitializerException('Unable to access the Step Position and Sequence Name');
         }
         Step__c  step = steps[0];
 
        //get group identifier instruction from config
        AuditInitializerConfig__c config;
        try {
            config = (AuditInitializerConfig__c)SalesforceObject.getById(this.StepConfig.Id);
        } catch (System.QueryException e) {
            throw new AuditInitializerException('Unable to access AuditInitializerConfig');
        }
        
         // insert composite key values into audit group :
         // the composite key comprises
         // 1.  the date-time stamp
         // 2.  a (fairly unique ) business group value
         Id dataId =  (Id)parameters.get('esb__Id');
         String groupIdentifier = getBusinesGroupIdentifier(config, step, dataId) ;
         DateTime now = System.Now();
         AuditGroup__c auditGroup = new AuditGroup__c(
             Name = ((''+now).replace(' ','T'))+'Z' + ' - ' + groupIdentifier,
             AuditInitializerConfig__c = config.Id,
             GroupIdentifier__c = groupIdentifier,
             Stamp__c = now
         );
         insert auditGroup;

         // update outbound message
         List<Object> auditGroupIds = (List<Object>)parameters.get('esb__AuditGroupIds');
         if (auditGroupIds == null) {
             auditGroupIds = new List<Object>();
         }
         auditGroupIds.add(auditGroup.Id);
         parameters.put('esb__AuditGroupIds', auditGroupIds);

         
         return Json.serialize(new List<Map<String,Object>>{parameters});
    }

 
    
    @TestVisible private static SObject getHydrated(Id theId) {
        try {
            return SalesforceObject.getById(theId);
        } catch (Exception e) {
            throw new AuditInitializerException('Cannot hydate SObject with Id=[' + theId + ']', e);
        }
    }


    @TestVisible private static String getIdentifer(String key, SObject so) {
        return (String) so.get(key);
    }
    
    
    @TestVisible private static String getBusinesGroupIdentifier(AuditInitializerConfig__c config, Step__c  step,  Id dataId) {

        //  default :
        //
        //  "sequence name" and "step position"
        //  (always use this if StaticGroupIdentifier__c from config equates to null)
        String defaultGroupIdentifier =  step.Sequence__r.Name + '-' + step.Position__c;
        
        
        //  preferred alternatives :
        //
        //     alternative 1  use non-null StaticGroupIdentifier__c from config
        //     even better
        //     alternative 2  attempt obtain a user friendly "business id" from the
        //                    object by defining a field of that object in the
        //                    DynamicGroupIdentifier__c field
        //                    if successful, any entry in StaticGroupIdentifier__c is ignored
        
        String groupIdentifier =  config.StaticGroupIdentifier__c;
        String dynamicGroupIdentifier =  config.DynamicGroupIdentifier__c;
        
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