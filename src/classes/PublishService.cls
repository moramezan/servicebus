public class PublishService extends ApexClassModel.Service {
    void callout(Map<String,Object> inputEvent) {}
    
    public class Summary extends ApexClassModel.Summary {
        String Tag = 'Service Bus';
        String Label = 'Publish';
        String Description = 'Broadcasts named events to other subscribed sequences.';
        String StepConfig = PublishStepConfig__c.class.getName();
        String Icon = 'chart_organisation';
        Integer Chunks = 33; //max sync limit
        String Cardinality = 'One';
    }
    
    public class ServiceException extends Exception {}

    List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
        
        String stepConfigId = (Id)inputEvent.get('StepConfigId');
        if (stepConfigId == null) throw new ServiceException('Null step config id.');
        
        String route = (String)inputEvent.get('Route');
        if (route == null) throw new ServiceException('Null route.');
        
        PublishStepConfig__c publishConfig = [
            SELECT Topic__c
            FROM PublishStepConfig__c
            WHERE Id = :stepConfigId
        ];
        
        String topic = publishConfig.Topic__c;
        if (topic == null) throw new ServiceException('No topic.');
        
        List<SubscribeStepConfig__c> subscribeConfigs = [
            SELECT Id
            FROM SubscribeStepConfig__c
            WHERE Topic__c = :topic
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
        
        //original guy carries on... this does not inadvertently terminate
        outputEvents.add(inputEvent);
        
        return outputEvents;
    }
}