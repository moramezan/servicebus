public with sharing class Publish {
    
    public String Parameters;
    public SObject StepConfig;
    
    public class Meta {
        public String Tag = 'Event Driven Architecture';
        public String Name = 'Publish';
        public String Description = 'Broadcasts the message to other sequences via a named Event Type.';
        public SObject StepConfig = PublishConfig__c.SObjectType.newSObject();
        public String Icon = 'chart_organisation';
        public String HelpUrl = Page.PublishConfigCsh.getUrl();
    }
    
    public class PublishException extends Exception {}

    override public String toString() {
        Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(this.Parameters);
        List<Map<String,Object>> parametersList = new List<Map<string,object>>();
        
        PublishConfig__c publishConfig = (PublishConfig__c)this.StepConfig;
        
        if (publishConfig == null || publishConfig.EventType__c == null) {
            throw new PublishException('Publish Config ' + publishConfig + ' has no Event type');
        }
        
        Map<Id,SObject> subscribeConfigs = new Map<Id,SObject>([
            SELECT Id
            FROM SubscribeConfig__c
            WHERE EventType__c = :publishConfig.EventType__c
        ]);
        
        List<Step__c> steps = [
            SELECT Id, Sequence__r.Name, Position__c
            FROM Step__c
            WHERE ConfigId__c IN :subscribeConfigs.keySet()
        ];
        
        for (Step__c step : steps) {
            Map<String,Object> clone = parameters.clone();
            //#47: Any messages properties affecting the TERMINATE behaviour should be stripped from FLOW CONTROL
            clone.put('eda_SubsequenceStepIds', null);
            clone.put('eda_Position', step.Position__c);
            clone.put('eda_SequenceName', step.Sequence__r.Name);
            parametersList.add(clone);
        }
        
        //original guy carries on... this is not a Terminate
        parametersList.add(parameters);
        
        return Json.serialize(parametersList);
    }
}