public class Publish extends ApexClassModel.BaseProcess {
    
    /**
     * @docs ProcessPublishSubscribe.html
     */
    public class ESB extends ApexClassModel.BaseSummary {
        String Tag = 'Enterprise Service Bus';
        String Name = 'Publish';
        String Description = 'Broadcasts the message to other sequences via a named Event Type.';
        String StepConfig = PublishConfig__c.class.getName();
        String Icon = 'chart_organisation';
        String HelpUrl = new PageReference('/apex/ContextSensitiveHelp?topic=ProcessPublishSubscribe').getUrl();
        Integer Limits = 33; //max sync limit
        String Cardinality = 'One';
    }
    
    public class PublishException extends Exception {}

    List<Map<String,Object>> execute(Map<String,Object> parameters) {
        List<Map<String,Object>> parametersList = new List<Map<string,object>>();
        
        PublishConfig__c publishConfig = (PublishConfig__c)ApexDomain.getById((Id)parameters.get('esb__StepConfigId'));
        
        if (publishConfig == null || publishConfig.EventType__c == null) {
            throw new PublishException('Publish Config ' + publishConfig + ' has no Event type');
        }
        
        Map<Id,SObject> subscribeConfigs = new Map<Id,SObject>([
            SELECT Id
            FROM SubscribeConfig__c
            WHERE EventType__c = :publishConfig.EventType__c
        ]);
        
        List<Step__c> steps = [
            SELECT Id, SequenceName__c, Position__c
            FROM Step__c
            WHERE ConfigId__c IN :subscribeConfigs.keySet()
        ];
        
        for (Step__c step : steps) {
            Map<String,Object> clone = parameters.clone();
            //#47: Any messages properties affecting the TERMINATE behaviour should be stripped from FLOW CONTROL
            clone.put('__SubsequenceStepIds', null);
            clone.put('__Position', step.Position__c.intValue());
            clone.put('__SequenceName', step.SequenceName__c);
            parametersList.add(clone);
        }
        
        //original guy carries on... this is not a Terminate
        parametersList.add(parameters);
        
        return parametersList;
    }
}