public with sharing class AuditWriter {
    
    public String Parameters;
    
    /**
     * @docs ProcessAudit.html
     */
    public class ESB {
        public String Tag = 'Enterprise Service Bus';
        public String Name = 'Audit Writer';
        public String Description = 'Stores the message parameters under an Audit Group.';
        public String Icon = 'pencil_add';
        public String HelpUrl = new PageReference('/apex/Csh?topic=ProcessAudit').getUrl();
        public Integer Limits = 50; //leave half of 200 (Total number of SOQL queries issued)
    }
    
    public class AuditWriterException extends Exception {}
    
    override public String toString() {
        if (!SObjectType.AuditEntry__c.Createable) throw new SalesforceObject.CrudException('!SObjectType.AuditEntry__c.Createable');
        
        Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(this.Parameters);
        List<Map<String,Object>> parametersList = new List<Map<String,Object>>();
        
        Integer parametersOrder = (Integer)parameters.get('__Hops');
        parametersOrder = (parametersOrder != null) ? parametersOrder : 1;
        
        String entryPointGuid = (String)parameters.get('__EntryPointGuid');
        if (String.isBlank(entryPointGuid)) {
            throw new AuditWriterException('Unable to access the Entry Point GUID');
        }
                
        //derive the Step
        List<Step__c> steps = [
            SELECT Id, Position__c, Sequence__c
            FROM Step__c
            WHERE Sequence__r.Name = :(String)parameters.get('__SequenceName')
            AND Position__c = :(Decimal) parameters.get('__Position')
        ];
        if (steps.size() == 0) {
            throw new AuditWriterException('Unable to access the Step');
        }
        Step__c step = steps[0];
 
        //write audit entry for every audit group identifier
        List<Object> collection = (List<Object>)parameters.get('esb__AuditGroupIds');
        
        if (collection != null) {
            List<Id> auditGroupIds = new List<Id>();
            for (Object c : collection) {
                if  (c != null) {
                  auditGroupIds.add((Id) c );  
                }
            }
            Set<Id> filteredAuditGroupIds = (new Map<Id,AuditGroup__c>([
                SELECT Id, Name
                FROM AuditGroup__c
                WHERE Id IN :auditGroupIds
            ])).keySet();
        
            String serializedParameters = System.Json.serializePretty(parameters);
            List<AuditEntry__c> auditEntries =  new List<AuditEntry__c>();
            for (Id auditGroupId  : filteredAuditGroupIds) {
                auditEntries.add( new AuditEntry__c(
                    Step__c = step.Id,
                    Sequence__c = step.Sequence__c,
                    Hops__c = parametersOrder,
                    AuditGroup__c     = auditGroupId,
                    EntryPointGuid__c = entryPointGuid,
                    Parameters__c    = serializedParameters
                ));
            }
            insert auditEntries;
        }

        parametersList.add(parameters);
        
        return Json.serialize(parametersList);
    }
}