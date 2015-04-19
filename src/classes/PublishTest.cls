@IsTest private class PublishTest {

    static testmethod void hasTheCorrectLimits() {
        //assert
        Integer expectedLimits = 50;
        Integer actualLimits = new Publish.ESB().Limits;
        System.assertEquals(expectedLimits, actualLimits);
    }
    
    
    
    static testmethod void testSubsequenceDropped() {
        //arrange events
        EventType__c eventType = new EventType__c(
            Name = 'ready'
        );
        insert eventType;
        
        //arrange publish config
        PublishConfig__c pubConfig = new PublishConfig__c(
            EventType__c = eventType.Id
        );
        insert pubConfig;
        
        //arrange sequence
        Sequence__c target = new Sequence__c(Name = 'target');
        insert target;
        
        Step__c subscribeStep = SequenceModel.fromName(target.Name).appendStep(Subscribe.class.getName());
        
        //arrange subscribe config
        Database.update(new SubscribeConfig__c(
            Id = subscribeStep.ConfigId__c,
            EventType__c = eventType.Id
        ));
        
        Map<String,Object> parameters = new Map<String,Object>{
            'esb__StepConfig' => pubConfig,
            '__SubsequenceStepIds' => new List<Id>{'000000000000000AAA'}
        };
        
        ProcessModel.BaseProcess process = new Publish();
        List<Map<String,Object>> parametersList = process.execute(parameters);
        
        //should return one for sub, one for passthru
        Integer expectedSize = 2;
        Integer actualSize = parametersList.size();
        System.assertEquals(expectedSize, actualSize);
        
        //first one is for subscriber
        List<Object> expectedIds = null;
        List<Object> actualIds = (List<Object>)parametersList[0].get('__SubsequenceStepIds');
        System.assertEquals(expectedIds, actualIds);
        
        //second one is original/passthru
        expectedIds = new List<Id>{'000000000000000AAA'};
        actualIds = (List<Object>)parametersList[1].get('__SubsequenceStepIds');
        System.assertEquals(expectedIds, actualIds);
    }
    
    static testmethod void testUnconfiguredPublishProcessThrowsException() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange steps
        Step__c step = SequenceModel.fromName(sequence.Name).appendStep(Publish.class.getName());
        
        PublishConfig__c config = new PublishConfig__c();
        insert config;
        
        Map<String,Object> parameters = new Map<String,Object>{'__SequenceName' => 'TestSequence', '__Position' => 1};
        
        //act
        Boolean thrown = false;
        ProcessModel.BaseProcess process = new Publish();
        try {process.execute(parameters);}
        catch (Publish.PublishException e) {thrown = true;}
        
        //assert
        System.assert(thrown);
    }
    
    static testmethod void testNoSubscribersStillReturnsOneMessage() {
        EventType__c eventType = new EventType__c(
            Name = 'TestEvent'
        );
        insert eventType;
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange steps
        Step__c step = SequenceModel.fromName(sequence.Name).appendStep(Publish.class.getName());
        PublishConfig__c config = new PublishConfig__c(
            Id = step.ConfigId__c,
            EventType__c = eventType.Id
        );
        update config;
        
        String data = '{"__SequenceName":"TestSequence","__Position":1}';
        Map<String,Object> parameters = (Map<String,Object>)System.Json.deserializeUntyped(data);
        parameters.put('esb__StepConfig', config);
        //act
        ProcessModel.BaseProcess process = new Publish();
        List<Map<String,Object>> parametersList = process.execute(parameters);
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = parametersList.size();
        System.assertEquals(expectedSize, actualSize);
    }
    
    static testmethod void testSubscribersAffectOutputEventsReturned() {
        EventType__c eventType = new EventType__c(
            Name = 'TestEvent'
        );
        insert eventType;
        
        //arrange publish sequences and steps
        Sequence__c publisher = new Sequence__c(Name = 'Publisher');
        insert publisher;
        
        Step__c publisherStep = SequenceModel.fromName(publisher.Name).appendStep(Publish.class.getName());
        PublishConfig__c pubConfig = new PublishConfig__c(
            Id = publisherStep.ConfigId__c,
            EventType__c = eventType.Id
        );
        update pubConfig;
        
        //arrange subscribe sequences and steps
        Sequence__c subscriber1 = new Sequence__c(Name = 'Subscriber1');
        insert subscriber1;
        
        Step__c subscriber1step = SequenceModel.fromName(subscriber1.Name).appendStep(Subscribe.class.getName());
        Database.update(new SubscribeConfig__c(
            Id = subscriber1step.ConfigId__c,
            EventType__c = eventType.Id
        ));
        
        Sequence__c subscriber2 = new Sequence__c(Name = 'Subscriber2');
        insert subscriber2;
        
        Step__c subscriber2step = SequenceModel.fromName(subscriber2.Name).appendStep(Subscribe.class.getName());
        Database.update(new SubscribeConfig__c(
            Id = subscriber2step.ConfigId__c,
            EventType__c = eventType.Id
        ));
        
        //arrange
        Map<String,Object> parameters = new Map<String,Object>{'__SequenceName' => 'Publisher', '__Position' => 1, 'esb__StepConfig' => pubConfig};
        
        //act
        ProcessModel.BaseProcess process = new Publish();
        List<Map<String,Object>> parametersList = process.execute(parameters);
        
        //assert
        Integer expectedSize = 3;
        Integer actualSize = parametersList.size();
        System.assertEquals(expectedSize, actualSize);
    }
    
}