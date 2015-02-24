public with sharing class AuditWriter {
    
    public String Event;
    
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
        if (!SObjectType.AuditEntry__c.Createable) throw new ApexDomain.CrudException('!SObjectType.AuditEntry__c.Createable');
        
        Map<String,Object> inputEvent = (Map<String,Object>)Json.deserializeUntyped(this.Event);
        List<Map<String,Object>> outputEvents = new List<Map<String,Object>>();
        
        Integer hops = (Integer)inputEvent.get('__Hops');
        hops = (hops != null) ? hops : 1;
        
        String entryPointUuid = (String)inputEvent.get('__EntryPointUuid');
        if (String.isBlank(entryPointUuid)) {
            throw new AuditWriterException('Unable to access the Entry Point UUID');
        }
                
        //derive the Step
        List<Step__c> steps = [
            SELECT Id, Position__c, Sequence__c
            FROM Step__c
            WHERE Sequence__r.Name = :(String)inputEvent.get('__SequenceName')
            AND Position__c = :(Decimal)inputEvent.get('__Position')
        ];
        if (steps.size() == 0) {
            throw new AuditWriterException('Unable to access the Step');
        }
        Step__c step = steps[0];
 
        //write audit entry for every audit group identifier
        List<Object> collection = (List<Object>)inputEvent.get('esb__AuditGroupIds');
        
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
        
            String serializedEvent = System.Json.serializePretty(inputEvent);
            List<AuditEntry__c> auditEntries =  new List<AuditEntry__c>();
            for (Id auditGroupId  : filteredAuditGroupIds) {
                auditEntries.add( new AuditEntry__c(
                    Step__c = step.Id,
                    Sequence__c = step.Sequence__c,
                    Hops__c = hops,
                    AuditGroup__c     = auditGroupId,
                    EntryPointUuid__c = entryPointUuid,
                    Event__c    = serializedEvent
                ));
            }
            insert auditEntries;
        }

        outputEvents.add(inputEvent);
        
        return Json.serialize(outputEvents);
    }
}