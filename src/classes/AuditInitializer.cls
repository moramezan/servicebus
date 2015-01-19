public with sharing class AuditInitializer {
    
    public String Parameters;
    public AuditInitializerConfig__c StepConfig;
    
    /**
     * @docs ProcessAudit.html
     */
    public class ESB {
        public String Tag = 'Enterprise Service Bus';
        public String Name = 'Audit Initializer';
        public String Description = 'Creates a grouping identifier which all subsequent Audit Writer processes audit against.';
        public SObject StepConfig = AuditInitializerConfig__c.SObjectType.newSobject();
        public String Icon = 'pencil';
        public String HelpUrl = new PageReference('/apex/Csh?topic=ProcessAudit').getUrl();
        public Integer Limits = 75; //leave half of 150 (Total number of DML statements issued)
        
        public Map<String,String> Outputs = new Map<String,String>{
            'esb__AuditGroupIds' => 'LIST<ID> of potentially multiple groups from AuditInitializer steps.'
        };
        
    }
    
    public class AuditInitializerException extends Exception {}
    
    override public String toString() {
        if (!SObjectType.AuditGroup__c.Createable) throw new SalesforceObject.CrudException('!SObjectType.AuditGroup__c.Createable');
     
        Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(this.Parameters);
        List<Map<String,Object>> parametersList = new List<Map<String,Object>>();
        
        //get group identifier instruction from config
        AuditInitializerConfig__c config = this.StepConfig;
        
         // insert composite key values into audit group :
         // the composite key comprises
         // 1.  the date-time stamp
         // 2.  a (fairly unique ) business group value
         Id dataId =  (Id)parameters.get('esb__Id');
         String groupIdentifier = getBusinesGroupIdentifier(config, (String)parameters.get('__SequenceName') + '#' + (Decimal) parameters.get('__Position'), dataId) ;
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
    
    
    @TestVisible private static String getBusinesGroupIdentifier(AuditInitializerConfig__c config, String  step,  Id dataId) {

        //  default :
        //
        //  "sequence name" and "step position"
        //  (always use this if StaticGroupIdentifier__c from config equates to null)
        String defaultGroupIdentifier =  step;
        
        
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