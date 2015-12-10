@IsTest class JobTest {
    
    //TODO needs more tests
    
    class MockJob implements System.Schedulable {
        public void execute(System.SchedulableContext context) {}
    }
    
    class QueueableContext implements System.QueueableContext {
        Id jobId;
        public QueueableContext() {this.jobId = System.schedule('test', '0 0 * * * ?', new MockJob());}
        public Id getJobId() {return this.jobId;}
    }
    
    @TestSetup static void testSetup() {
        //act
        upsert BrokerSetting__c.getOrgDefaults();
        
        //assert
        System.assertNotEquals(null, BrokerSetting__c.getOrgDefaults().Id, 'Wrong id.');
    }
    
    static testmethod void testSimpleEventConstructor() {
        //arrange
        String sequenceName = 'Test';
        String recordId = UserInfo.getOrganizationId();
        
        //act
        Test.startTest();
        Job job = new Job(sequenceName, recordId);
        Enqueue.Queue queue = (Enqueue.Queue)job.queue;
        System.assert(queue.Events[0].containsKey('servicebus:ToSequence'), 'Wrong sequence key.');
        System.assert(queue.Events[0].containsKey('Route'), 'Wrong route key.');
        
        System.enqueueJob(job);
        Test.stopTest();
        
        //assert
        
        //assemble
        List<Message__c> messages = [SELECT Id, Event__c FROM Message__c];
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = messages.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong number of messages.');
        
        //assemble
        Map<String,Object> event = (Map<String,Object>)Json.deserializeUntyped(messages[0].Event__c);
        
        //assert
        System.assert(event.containsKey('Hops'));
        System.assert(event.containsKey('EntryPointTimestamp'));
        System.assert(event.containsKey('RecordId'));
        System.assert(event.containsKey('Route'));
        System.assert(event.containsKey('EnqueuedById'));
        System.assert(event.containsKey('CorrelationUuid'));
    }
    
    static testmethod void testUnpersistableTypesDetectedInConstructor() {
        //arrange
        Map<String,Object> input = new Map<String,Object>{
            'naughty' => Terminate.class
        };
        
        try {
            //act
            new Job(input);
            System.assert(false, 'Line above should throw exception');
        } catch (Enqueue.EnqueueException e) {
            //assert
            String expectedMessage = 'Type unsupported in JSON: common.apex.runtime.bytecode.BytecodeApexObjectType';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage);
        }
    }
    
    static testmethod void testEnoughDmlRowsToEnqueueManyEvents() {
        //arrange input events
        List<Map<String,Object>> inputEvents = new List<Map<String,Object>>();
        for (Integer i = 0; i < 1000; i++) inputEvents.add(new Map<String,Object>()); //#955 possibly 10000, but headspace
        
        //assert
        Test.startTest(); //avoid System.LimitException: Apex CPU time limit exceeded
        Integer expectedBefore = 0;
        Integer actualBefore = Limits.getDmlRows();
        System.assertEquals(expectedBefore, actualBefore, 'Wrong size.');

        //act
        Job job = new Job(inputEvents);
        job.execute(new QueueableContext());
        Integer limitDmlRows = Limits.getLimitDmlRows();
        Integer dmlRows = Limits.getDmlRows();
        Test.stopTest();
        
        //assert
        Integer expectedLimit = 10000;
        Integer actualLimit = limitDmlRows;
        System.assertEquals(expectedLimit, actualLimit, 'Wrong size.');
        
        //x2 due to #1038 we are doing update immediately after insert
        Integer expectedAfter = 2000; //#955 possibly 10000, but headspace
        Integer actualAfter = dmlRows;
        System.assertEquals(expectedAfter, actualAfter, 'Wrong size.');
    }
    
    static testmethod void testTooManyEventsDetectedInConstructor() {
        //arrange input events
        List<Map<String,Object>> inputEvents = new List<Map<String,Object>>();
        for (Integer i = 0; i < 1001; i++) inputEvents.add(new Map<String,Object>()); //#955 possibly 10001, but headspace
        
        try {
            //act
            new Job(inputEvents);
            System.assert(false, 'Line above should throw exception.');
        } catch (Enqueue.EnqueueException e) {
            //assert
            String expectedMessage = 'Too many events: 1001';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage, 'Wrong message.');
        }
        
    }
    
    static testmethod void testNaughtyKeys() {
        //act (good one)
        Map<String,Object> inputEvent = new Map<String,Object>{'ns:param' => ''};
        new Job(inputEvent);
        System.assert(inputEvent.containsKey('ns:param'));
        
        try {
            //act (ours)
            inputEvent = new Map<String,Object>{'test' => ''};
            new Job(inputEvent);
            System.assert(false, 'Line above should throw exception.');
            
        } catch (Enqueue.EnqueueException e) {
            //assert
            String expectedException = 'not supported';
            String actualException = e.getMessage();
            System.assert(actualException.contains(expectedException), 'Wrong exception.');
        }
        
        try {
            //act (reserved)
            inputEvent = new Map<String,Object>{':test' => ''};
            new Job(inputEvent);
            System.assert(false, 'Line above should throw exception.');
            
        } catch (Enqueue.EnqueueException e) {
            //assert
            String expectedException = 'not supported';
            String actualException = e.getMessage();
            System.assert(actualException.contains(expectedException), 'Wrong exception.');
        }
    }
    
    static testmethod void testEnqueueNormalizesSequenceAndServiceAndConfigToRoute() {
        //arrange
        Map<String,Object> inputEvent;
        List<Map<String,Object>> inputEvents;
        Object expectedParam;
        Object actualParam;
        Enqueue.Queue queue;
        Job job;
        
        //act
        inputEvent = new Map<String,Object>{'ToSequence' => 'Test'};
        job = new Job(inputEvent);
        queue = (Enqueue.Queue)job.queue;
        inputEvents = queue.Events;
        
        //assert
        expectedParam = '1#Test#0';
        actualParam = inputEvents[0].get('Route');
        System.assertEquals(expectedParam, actualParam, 'Wrong param.');
        
        expectedParam = 'Test';
        actualParam = inputEvents[0].get('servicebus:ToSequence');
        System.assertEquals(expectedParam, actualParam, 'Wrong param.');
        
        //act
        inputEvent = new Map<String,Object>{'ToService' => 'Wiretap'};
        job = new Job(inputEvent);
        queue = (Enqueue.Queue)job.queue;
        inputEvents = queue.Events;
        
        //assert
        expectedParam = 'Wiretap';
        actualParam = inputEvents[0].get('Route');
        System.assertEquals(expectedParam, actualParam, 'Wrong param.');
        
        expectedParam = 'Wiretap';
        actualParam = inputEvents[0].get('servicebus:ToService');
        System.assertEquals(expectedParam, actualParam, 'Wrong param.');
        
        //arrange
        Document document = new Document(Name = 'Config', FolderId = UserInfo.getUserId());
        insert document;
        
        Step__c step = new Step__c(Name = 'Test#1', Sequence__c = 'Test', ConfigId__c = document.Id);
        insert step;
        
        //act
        inputEvent = new Map<String,Object>{'ToConfigIds' => new List<Id>{document.Id}};
        job = new Job(inputEvent);
        queue = (Enqueue.Queue)job.queue;
        inputEvents = queue.Events;
        
        //assert
        expectedParam = '1#Test#0';
        actualParam = inputEvents[0].get('Route');
        System.assertEquals(expectedParam, actualParam, 'Wrong param.');
        
        expectedParam = document.Id;
        actualParam = inputEvents[0].get('servicebus:ToConfigIds');
        System.assertEquals(expectedParam, actualParam, 'Wrong param.');
    }
    
}