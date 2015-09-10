public class Publish extends ApexClassModel.Service {
    void callout(Map<String,Object> inputEvent) {}
    
    public class Summary {
        String Tag = 'Service Bus';
        String Name = 'Publish';
        String Description = 'Broadcasts the message to other sequences via a named Event Type.';
        String StepConfig = PublishConfig__c.class.getName();
        String Icon = 'chart_organisation';
        String HelpUrl = new PageReference('/apex/ContextSensitiveHelp?topic=ServicePublishSubscribe').getUrl();
        Integer Limits = 33; //max sync limit
        String Cardinality = 'One';
    }
    
    public class PublishException extends Exception {}

    List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
        
        String stepConfigId = (Id)inputEvent.get('StepConfigId');
        if (stepConfigId == null) throw new PublishException('Null step config id.');
        
        PublishConfig__c publishConfig = [
            SELECT EventType__c
            FROM PublishConfig__c
            WHERE Id = :stepConfigId
        ];
        
        Id eventTypeId = publishConfig.EventType__c;
        if (eventTypeId == null) throw new PublishException('No event type.');
        
        List<SubscribeConfig__c> subscribeConfigs = [
            SELECT Id
            FROM SubscribeConfig__c
            WHERE EventType__c = :eventTypeId
        ];
        
        List<Step__c> steps = [
            SELECT SequenceName__c
            FROM Step__c
            WHERE ConfigId__c IN :new Map<Id,SObject>(subscribeConfigs).keySet()
        ];
        
        List<Map<String,Object>> outputEvents = new List<Map<String,Object>>();
        for (Step__c step : steps) outputEvents.add(new Map<String,Object>{
            'Route' => step.SequenceName__c + '#0' //#1024 zero not one
        });
        
        //original guy carries on... this does not inadvertently Terminate
        outputEvents.add(inputEvent);
        
        return outputEvents;
    }
}