@IsTest class PublishTest {

    static testmethod void hasTheCorrectLimits() {
        //arrange
        ApexClassModel.Summary summary = new ApexClassModel.Summary(Publish.class);
        
        //assert
        Integer expectedLimits = 33; //max sync limit
        Integer actualLimits = summary.Limits;
        System.assertEquals(expectedLimits, actualLimits);
    }
    
   static testmethod void withinSystemLimits() {
        
        //arrange publisher config
        PublishConfig__c pubConfig = new PublishConfig__c(Name = UserInfo.getUserId(), EventType__c = 'Test');
        insert pubConfig;
        
        //arrange subscriber 1 sequence, step, config
        Sequence__c sub1 = new Sequence__c(Name = 'Subscriber1');
        insert sub1;
        
        Step__c sub1step = SequenceModel.fromName(sub1.Name).appendStep(Subscribe.class);
        Id sub1configId = new StepModel(sub1step).upsertConfig();
        
        SubscribeConfig__c sub1config = new SubscribeConfig__c(Id = sub1configId, EventType__c = 'Test');
        update sub1config;
        
        //arrange subscriber 2 sequence, step, config
        Sequence__c sub2 = new Sequence__c(Name = 'Subscriber2');
        insert sub2;
        
        Step__c sub2step = SequenceModel.fromName(sub2.Name).appendStep(Subscribe.class);
        Id sub2configId = new StepModel(sub2step).upsertConfig();
        
        SubscribeConfig__c sub2config = new SubscribeConfig__c(Id = sub2configId, EventType__c = 'Test');
        update sub2config;
        
        //arrange input
        Map<String,Object> inputEvent = new Map<String,Object>{
            'Route' => '1#Route#1',
            'StepConfigId' => pubConfig.Id
        };
        
        //assemble
        ApexClassModel.Summary summary = new ApexClassModel.Summary(Publish.class);
        
        //act
        Test.startTest();
        Integer limits = summary.Limits;
        Integer counter = 0;
        for (Integer i = 0; i < limits; i++) {
            ApexClassModel.Service service = new Publish();
            List<Map<String,Object>> outputs = service.handle(inputEvent);
            counter++;
        }
        Test.stopTest();

        //assert
        System.assertEquals(limits, counter, 'Limit not reached.');
   }

    static testmethod void testUnconfiguredPublishThrowsException() {
        //arrange input
        Map<String,Object> parameters = new Map<String,Object>{
            'StepConfigId' => null
        };
        
        try {
            //act
            ApexClassModel.Service service = new Publish();
            service.handle(parameters);
            System.assert(false, 'Line above should throw exception.');
        } catch (Publish.ServiceException e) {
            //assert
            String expectedMessage = 'Null step config id.';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage, 'Wrong message.');
        }
    }
    
    static testmethod void testNoSubscribersStillReturnsOneMessage() {
        
        //arrange publisher config
        PublishConfig__c pubConfig = new PublishConfig__c(Name = UserInfo.getUserId(), EventType__c = 'Test');
        insert pubConfig;
        
        //arrange input
        Map<String,Object> inputEvent = new Map<String,Object>{
            'Route' => '1#Test#1',
            'StepConfigId' => pubConfig.Id
        };
        
        //act
        ApexClassModel.Service service = new Publish();
        List<Map<String,Object>> outputEvents = service.handle(inputEvent);
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
    }
    
    static testmethod void testSubscribersAffectOutputEventsReturned() {
        
        //arrange publish config
        PublishConfig__c pubConfig = new PublishConfig__c(Name = UserInfo.getUserId(), EventType__c = 'Test');
        insert pubConfig;
        
        //arrange subscriber 1 sequence, step, config
        Sequence__c sub1 = new Sequence__c(Name = 'Subscriber1');
        insert sub1;
        
        Step__c sub1step = SequenceModel.fromName(sub1.Name).appendStep(Subscribe.class);
        Id sub1configId = new StepModel(sub1step).upsertConfig();
        
        SubscribeConfig__c sub1config = new SubscribeConfig__c(Id = sub1configId, EventType__c = 'Test');
        update sub1config;
        
        //arrange subscriber 2 sequence, step, config
        Sequence__c sub2 = new Sequence__c(Name = 'Subscriber2');
        insert sub2;
        
        Step__c sub2step = SequenceModel.fromName(sub2.Name).appendStep(Subscribe.class);
        Id sub2configId = new StepModel(sub2step).upsertConfig();
        
        SubscribeConfig__c sub2config = new SubscribeConfig__c(Id = sub2configId, EventType__c = 'Test');
        update sub2config;
        
        //arrange input
        Map<String,Object> inputEvent = new Map<String,Object>{
            'Route' => '1#Test#1',
            'StepConfigId' => pubConfig.Id
        };
        
        //act
        ApexClassModel.Service service = new Publish();
        List<Map<String,Object>> outputEvents = service.handle(inputEvent);
        
        //assert
        Integer expectedSize = 3;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
        
        //assemble
        Map<String,Object> outputEvent = outputEvents[0];
        
        //assert
        String expectedSequence = '1#Subscriber1#0';
        String actualSequence = (String)outputEvent.get('Route');
        System.assertEquals(expectedSequence, actualSequence, 'Wrong sequence.');
    }
    
}