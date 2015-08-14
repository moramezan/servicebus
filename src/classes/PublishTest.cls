@IsTest private class PublishTest {

    static testmethod void hasTheCorrectLimits() {
        //arrange
        ApexClassModel.Summary summary = new ApexClassModel.Summary(Publish.class);
        
        //assert
        Integer expectedLimits = 33; //max sync limit
        Integer actualLimits = summary.Limits;
        System.assertEquals(expectedLimits, actualLimits);
    }
    
   static testmethod void withinSystemLimits() {
        //arrange event
        EventType__c eventType = new EventType__c(Name = 'Test');
        insert eventType;
        
        //arrange publisher config
        PublishConfig__c pubConfig = new PublishConfig__c(EventType__c = eventType.Id);
        insert pubConfig;
        
        //arrange subscriber 1 sequence, step, config
        Sequence__c sub1 = new Sequence__c(Name = 'Subscriber1');
        insert sub1;
        
        Step__c sub1step = SequenceModel.fromName(sub1.Name).appendStep(Subscribe.class);
        Id sub1configId = new StepModel(sub1step).upsertConfig();
        
        SubscribeConfig__c sub1config = new SubscribeConfig__c(Id = sub1configId, EventType__c = eventType.Id);
        update sub1config;
        
        //arrange subscriber 2 sequence, step, config
        Sequence__c sub2 = new Sequence__c(Name = 'Subscriber2');
        insert sub2;
        
        Step__c sub2step = SequenceModel.fromName(sub2.Name).appendStep(Subscribe.class);
        Id sub2configId = new StepModel(sub2step).upsertConfig();
        
        SubscribeConfig__c sub2config = new SubscribeConfig__c(Id = sub2configId, EventType__c = eventType.Id);
        update sub2config;
        
        //arrange input
        Map<String,Object> inputEvent = new Map<String,Object>{
            'esb__StepConfigId' => pubConfig.Id
        };
        
        //assemble
        ApexClassModel.Summary summary = new ApexClassModel.Summary(Publish.class);
        
        //act
        Test.startTest();
        Integer limits = summary.Limits;
        Integer counter = 0;
        for (Integer i = 0; i < limits; i++) {
            ApexClassModel.BaseProcess process = new Publish();
            List<Map<String,Object>> outputs = process.test(inputEvent);
            counter++;
        }
        Test.stopTest();

        //assert
        System.assertEquals(limits, counter, 'Limit not reached.');
   }

    
    static testmethod void testSubsequenceDropped() {
        //arrange event
        EventType__c eventType = new EventType__c(Name = 'Test');
        insert eventType;
        
        //arrange publish config
        PublishConfig__c pubConfig = new PublishConfig__c(EventType__c = eventType.Id);
        insert pubConfig;
        
        //arrange subscribe sequence, step, config
        Sequence__c sub = new Sequence__c(Name = 'Subscriber');
        insert sub;
        
        Step__c subStep = SequenceModel.fromName(sub.Name).appendStep(Subscribe.class);
        Id subConfigId = new StepModel(subStep).upsertConfig();
        
        SubscribeConfig__c subConfig = new SubscribeConfig__c(Id = subConfigId, EventType__c = eventType.Id);
        update subConfig;
        
        //arrange input
        Map<String,Object> parameters = new Map<String,Object>{
            'esb__StepConfigId' => pubConfig.Id,
            '__SubsequenceStepIds' => new List<Id>{'000000000000000AAA'}
        };
        
        ApexClassModel.BaseProcess process = new Publish();
        List<Map<String,Object>> parametersList = process.test(parameters);
        
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
        //arrange input
        Map<String,Object> parameters = new Map<String,Object>{
            'esb__StepConfigId' => null
        };
        
        try {
            //act
            ApexClassModel.BaseProcess process = new Publish();
            process.test(parameters);
            System.assert(false, 'Line above should throw exception.');
        } catch (Exception e) {
            //assert
            String expectedMessage = 'ApexDomain.getById received null recordId.';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage, 'Wrong message.');
        }
    }
    
    static testmethod void testNoSubscribersStillReturnsOneMessage() {
        //arrange event
        EventType__c eventType = new EventType__c(Name = 'TestEvent');
        insert eventType;
        
        //arrange publisher config
        PublishConfig__c pubConfig = new PublishConfig__c(EventType__c = eventType.Id);
        insert pubConfig;
        
        //arrange input
        Map<String,Object> inputEvent = new Map<String,Object>{
            'esb__StepConfigId' => pubConfig.Id
        };
        
        //act
        ApexClassModel.BaseProcess process = new Publish();
        List<Map<String,Object>> outputEvents = process.test(inputEvent);
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
    }
    
    static testmethod void testSubscribersAffectOutputEventsReturned() {
        //arrange event
        EventType__c eventType = new EventType__c(Name = 'TestEvent');
        insert eventType;
        
        //arrange publish config
        PublishConfig__c pubConfig = new PublishConfig__c(EventType__c = eventType.Id);
        insert pubConfig;
        
        //arrange subscriber 1 sequence, step, config
        Sequence__c sub1 = new Sequence__c(Name = 'Subscriber1');
        insert sub1;
        
        Step__c sub1step = SequenceModel.fromName(sub1.Name).appendStep(Subscribe.class);
        Id sub1configId = new StepModel(sub1step).upsertConfig();
        
        SubscribeConfig__c sub1config = new SubscribeConfig__c(Id = sub1configId, EventType__c = eventType.Id);
        update sub1config;
        
        //arrange subscriber 2 sequence, step, config
        Sequence__c sub2 = new Sequence__c(Name = 'Subscriber2');
        insert sub2;
        
        Step__c sub2step = SequenceModel.fromName(sub2.Name).appendStep(Subscribe.class);
        Id sub2configId = new StepModel(sub2step).upsertConfig();
        
        SubscribeConfig__c sub2config = new SubscribeConfig__c(Id = sub2configId, EventType__c = eventType.Id);
        update sub2config;
        
        //arrange input
        Map<String,Object> inputEvent = new Map<String,Object>{
            'esb__StepConfigId' => pubConfig.Id
        };
        
        //act
        ApexClassModel.BaseProcess process = new Publish();
        List<Map<String,Object>> outputEvents = process.test(inputEvent);
        
        //assert
        Integer expectedSize = 3;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
    }
    
}