public class Publish extends ApexClassModel.Service {
    void callout(Map<String,Object> inputEvent) {}
    
    public class Summary {
        String Tag = 'Service Bus';
        String Label = 'Publish';
        String Description = 'Broadcasts named events to other subscribed sequences.';
        String StepConfig = PublishConfig__c.class.getName();
        String Icon = 'chart_organisation';
        String HelpUrl = new PageReference('/apex/ContextSensitiveHelp?topic=ServicePublishSubscribe').getUrl();
        Integer Limits = 33; //max sync limit
        String Cardinality = 'One';
    }
    
    public class ServiceException extends Exception {}

    List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
        
        String stepConfigId = (Id)inputEvent.get('StepConfigId');
        if (stepConfigId == null) throw new ServiceException('Null step config id.');
        
        String route = (String)inputEvent.get('Route');
        if (route == null) throw new ServiceException('Null route.');
        
        PublishConfig__c publishConfig = [
            SELECT EventType__c
            FROM PublishConfig__c
            WHERE Id = :stepConfigId
        ];
        
        String eventType = publishConfig.EventType__c;
        if (eventType == null) throw new ServiceException('No event type.');
        
        List<SubscribeConfig__c> subscribeConfigs = [
            SELECT Id
            FROM SubscribeConfig__c
            WHERE EventType__c = :eventType
        ];
        
        Integer version = Integer.valueOf(route.substringBefore('#'));
        Integer position = 0;
        
        List<Step__c> steps = [
            SELECT Sequence__c
            FROM Step__c
            WHERE ConfigId__c IN :new Map<Id,SObject>(subscribeConfigs).keySet()
            AND Version__c = :version
        ];
        
        List<Map<String,Object>> outputEvents = new List<Map<String,Object>>();
        for (Step__c step : steps) outputEvents.add(new Map<String,Object>{
            'Route' => version + '#' + step.Sequence__c + '#0' //#1024 zero not one
        });
        
        //original guy carries on... this does not inadvertently Terminate
        outputEvents.add(inputEvent);
        
        return outputEvents;
    }
}