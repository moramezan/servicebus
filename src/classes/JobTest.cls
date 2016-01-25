@IsTest class JobTest {
    
    @TestSetup static void testSetup() {
        //act
        new PostInstallHandler().onInstall(null);
        
        //assert
        System.assertNotEquals(null, Application__c.getOrgDefaults().Id, 'Wrong id.');
    }
    
    //TODO needs more tests
    
    class MockJob implements System.Schedulable {
        public void execute(System.SchedulableContext context) {}
    }
    
    class QueueableContext implements System.QueueableContext {
        Id jobId;
        public QueueableContext() {this.jobId = System.schedule('test', '0 0 * * * ?', new MockJob());}
        public Id getJobId() {return this.jobId;}
    }
    
    static testmethod void testSimpleEventConstructor() {
        //arrange
        String sequenceName = 'Test';
        String recordId = UserInfo.getOrganizationId();
        
        //act
        Test.startTest();
        Enqueue.invoke(new Map<String,Object>{'ToSequence' => sequenceName, 'RecordId' => recordId});
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
            'naughty' => TerminateService.class
        };
        
        try {
            //act
            Enqueue.invoke(input);
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
        for (Integer i = 0; i < 1000; i++) inputEvents.add(new Map<String,Object>{'ToSequence' => 'Test'}); //#955 possibly 10000, but headspace
        
        //assert
        Test.startTest(); //avoid System.LimitException: Apex CPU time limit exceeded
        Integer expectedBefore = 0;
        Integer actualBefore = Limits.getDmlRows();
        System.assertEquals(expectedBefore, actualBefore, 'Wrong size.');

        //act
        Enqueue.invoke(inputEvents);
        Integer limitDmlRows = Limits.getLimitDmlRows();
        Integer dmlRows = Limits.getDmlRows();
        Test.stopTest();
        
        //assert
        Integer expectedLimit = 10000;
        Integer actualLimit = limitDmlRows;
        System.assertEquals(expectedLimit, actualLimit, 'Wrong size.');
        
        //#1226 no longer updating after insert, no longer x2
        Integer expectedAfter = 1000; //#955 possibly 10000, but headspace
        Integer actualAfter = dmlRows;
        System.assertEquals(expectedAfter, actualAfter, 'Wrong size.');
    }
    
    static testmethod void testTooManyEventsDetectedInConstructor() {
        //arrange input events
        List<Map<String,Object>> inputEvents = new List<Map<String,Object>>();
        for (Integer i = 0; i < 1001; i++) inputEvents.add(new Map<String,Object>()); //#955 possibly 10001, but headspace
        
        try {
            //act
            Enqueue.invoke(inputEvents);
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
        Map<String,Object> inputEvent = new Map<String,Object>{'ToSequence' => 'Test', 'ns:param' => ''};
        Enqueue.invoke(inputEvent);
        System.assert(inputEvent.containsKey('ns:param'));
        
        try {
            //act (ours)
            inputEvent = new Map<String,Object>{'ToSequence' => 'Test', 'test' => ''};
            Enqueue.invoke(inputEvent);
            System.assert(false, 'Line above should throw exception.');
            
        } catch (Enqueue.EnqueueException e) {
            //assert
            String expectedException = 'not supported';
            String actualException = e.getMessage();
            System.assert(actualException.contains(expectedException), 'Wrong exception.');
        }
        
        try {
            //act (reserved)
            inputEvent = new Map<String,Object>{'ToService' => '', ':test' => ''};
            Enqueue.invoke(inputEvent);
            System.assert(false, 'Line above should throw exception.');
            
        } catch (Enqueue.EnqueueException e) {
            //assert
            String expectedException = 'not supported';
            String actualException = e.getMessage();
            System.assert(actualException.contains(expectedException), 'Wrong exception.');
        }
    }
    
}