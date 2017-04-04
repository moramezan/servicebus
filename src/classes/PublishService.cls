public class PublishService extends ApexClassModel.Service {
    
    public class Definition extends ApexClassModel.Definition {
        String Tag = 'Services';
        String Label = 'Publish';
        String Description = 'Broadcasts named events to other subscribed sequences.';
        String StepConfig = PublishStepConfig__c.class.getName();
        String Icon = 'chart_organisation';
        Integer Chunks = 100; //performs 1 soql
        String Cardinality = 'One';
    }
    
    public class ServiceException extends Exception {}

    override public List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
        
        String stepConfigId = (Id)inputEvent.get('StepConfigId');
        if (stepConfigId == null) throw new ServiceException('Null step config id.');
        
        String route = (String)inputEvent.get('Route');
        if (route == null) throw new ServiceException('Null route.');
        
        PublishStepConfig__c config; //fetch without using soql
        List<PublishStepConfig__c> publishStepConfigs = PublishStepConfig__c.getAll().values();
        for (PublishStepConfig__c publishStepConfig : publishStepConfigs) if (publishStepConfig.Id == stepConfigId) config = publishStepConfig;
        
        String topic = config.Topic__c;
        if (topic == null) throw new ServiceException('No topic.');
        
        List<Id> configIds = new List<Id>(); //fetch without using soql
        List<SubscribeStepConfig__c> subscribeStepConfigs = SubscribeStepConfig__c.getAll().values();
        for (SubscribeStepConfig__c subscribeStepConfig : subscribeStepConfigs) if (subscribeStepConfig.Topic__c == config.Topic__c) configIds.add(subscribeStepConfig.Id);
        
        Integer version = Integer.valueOf(route.substringBefore('#'));
        Integer position = 0; //#1024 zero not one
        
        List<Step__c> steps = [
            SELECT Sequence__c
            FROM Step__c
            WHERE ConfigId__c IN :configIds
            AND Version__c = :version
        ];
        
        List<Map<String,Object>> outputEvents = new List<Map<String,Object>>();
        for (Step__c step : steps) outputEvents.add(new Map<String,Object>{
            'Route' => version + '#' + step.Sequence__c + '#' + position
        });
        
        //original guy carries on... this does not inadvertently terminate
        outputEvents.add(inputEvent);
        
        return outputEvents;
    }
}