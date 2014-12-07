@IsTest private class PublishTest {

    static testmethod void canDetermineStepConfig() {
        //arrange processes
        Process__c publishProcess = ProcessObject.generateOne(Publish.class);
        
        //act
        String actualConfig = publishProcess.StepConfig__c;
        
        //assert
        String expectedConfig = Schema.SObjectType.PublishConfig__c.Name;
        System.assertEquals(expectedConfig, actualConfig);
    }
    
    static testmethod void testSubsequenceDropped() {
        //arrange events
        EventType__c eventType = new EventType__c(
            Name = 'ready'
        );
        insert eventType;
        
        //arrange processes
        Process__c subscribeProcess = ProcessObject.generateOne(Subscribe.class);
        
        //arrange publish config
        PublishConfig__c pubConfig = new PublishConfig__c(
            EventType__c = eventType.Id
        );
        insert pubConfig;
        
        //arrange sequence
        Sequence__c target = new Sequence__c(Name = 'target');
        insert target;
        
        Step__c subscribeStep = StepObject.generateOne(target.Id, subscribeProcess.Id);
        
        //arrange subscribe config
        Database.update(new SubscribeConfig__c(
            Id = subscribeStep.ConfigId__c,
            EventType__c = eventType.Id
        ));
        
        Map<String,Object> parameters = new Map<String,Object>{
            'esb_SubsequenceStepIds' => new List<Id>{'000000000000000AAA'}
        };
        
        Type reflector = Publish.class;
        List<Map<String,Object>> parametersList = new Broker.Wrapper(reflector, parameters, pubConfig).invokeMain().Outputs;
        
        //should return one for sub, one for passthru
        Integer expectedSize = 2;
        Integer actualSize = parametersList.size();
        System.assertEquals(expectedSize, actualSize);
        
        //first one is for subscriber
        List<Object> expectedIds = null;
        List<Object> actualIds = (List<Object>)parametersList[0].get('esb_SubsequenceStepIds');
        System.assertEquals(expectedIds, actualIds);
        
        //second one is original/passthru
        expectedIds = new List<Id>{'000000000000000AAA'};
        actualIds = (List<Object>)parametersList[1].get('esb_SubsequenceStepIds');
        System.assertEquals(expectedIds, actualIds);
    }
    
    static testmethod void testUnconfiguredPublishProcessThrowsException() {
        //arrange processes
        Process__c publishProcess = ProcessObject.generateOne(Publish.class);
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange steps
        Step__c step = StepObject.generateOne(sequence.Id, publishProcess.Id);
        
        PublishConfig__c config = new PublishConfig__c();
        insert config;
        
        Map<String,Object> parameters = new Map<String,Object>{'esb_SequenceName' => 'TestSequence', 'esb_Position' => 1};
        
        //act
        Boolean thrown = false;
        Type reflector = Publish.class;
        try {new Broker.Wrapper(reflector, parameters, null).invokeMain();}
        catch (Publish.PublishException e) {thrown = true;}
        
        //assert
        System.assert(thrown);
    }
    
    static testmethod void testNoSubscribersStillReturnsOneMessage() {
        //arrange processes
        Process__c publishProcess = ProcessObject.generateOne(Publish.class);
        
        EventType__c eventType = new EventType__c(
            Name = 'TestEvent'
        );
        insert eventType;
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange steps
        Step__c step = StepObject.generateOne(sequence.Id, publishProcess.Id);
        PublishConfig__c config = new PublishConfig__c(
            Id = step.ConfigId__c,
            EventType__c = eventType.Id
        );
        update config;
        
        String data = '{"esb_SequenceName":"TestSequence","esb_Position":1}';
        Map<String,Object> parameters = (Map<String,Object>)System.Json.deserializeUntyped(data);
        
        //act
        Type reflector = Publish.class;
        List<Map<String,Object>> parametersList = new Broker.Wrapper(reflector, parameters, config).invokeMain().Outputs;
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = parametersList.size();
        System.assertEquals(expectedSize, actualSize);
        
        Integer expectedData = data.length();
        Integer actualData = System.Json.serialize(parametersList[0]).length();
        System.assertEquals(expectedData, actualData);
    }
    
    static testmethod void testSubscribersAffectParametersListReturned() {
        EventType__c eventType = new EventType__c(
            Name = 'TestEvent'
        );
        insert eventType;
        
        //arrange processes
        Process__c subscribeProcess = ProcessObject.generateOne(Subscribe.class);
        Process__c publishProcess = ProcessObject.generateOne(Publish.class);
        
        //arrange publish sequences and steps
        Sequence__c publisher = new Sequence__c(Name = 'Publisher');
        insert publisher;
        
        Step__c publisherStep = StepObject.generateOne(publisher.Id, publishProcess.Id);
        PublishConfig__c pubConfig = new PublishConfig__c(
            Id = publisherStep.ConfigId__c,
            EventType__c = eventType.Id
        );
        update pubConfig;
        
        //arrange subscribe sequences and steps
        Sequence__c subscriber1 = new Sequence__c(Name = 'Subscriber1');
        insert subscriber1;
        
        Step__c subscriber1step = StepObject.generateOne(subscriber1.Id, subscribeProcess.Id);
        Database.update(new SubscribeConfig__c(
            Id = subscriber1step.ConfigId__c,
            EventType__c = eventType.Id
        ));
        
        Sequence__c subscriber2 = new Sequence__c(Name = 'Subscriber2');
        insert subscriber2;
        
        Step__c subscriber2step = StepObject.generateOne(subscriber2.Id, subscribeProcess.Id);
        Database.update(new SubscribeConfig__c(
            Id = subscriber2step.ConfigId__c,
            EventType__c = eventType.Id
        ));
        
        //arrange
        Map<String,Object> parameters = new Map<String,Object>{'esb_SequenceName' => 'Publisher', 'esb_Position' => 1};
        
        //act
        Type reflector = Publish.class;
        List<Map<String,Object>> parametersList = new Broker.Wrapper(reflector, parameters, pubConfig).invokeMain().Outputs;
        
        //assert
        Integer expectedSize = 3;
        Integer actualSize = parametersList.size();
        System.assertEquals(expectedSize, actualSize);
    }
    
}