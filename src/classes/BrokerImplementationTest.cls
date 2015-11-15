@IsTest class BrokerImplementationTest {
    
    @TestSetup static void testSetup() {
        OAuthSetting__c setting = OAuthSetting__c.getOrgDefaults();
        setting.RunningUserId__c = UserInfo.getUserId();
        upsert setting;
    }
    
    static testmethod void testChunkedMarkContextsCount() {
        //arrange services and sequence and steps
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        Step__c wiretapStep = SequenceModel.fromName(sequence.Name).appendStep(Wiretap.class);
        Step__c terminateStep = SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
        
        //arrange messages
        Map<String,Object> inputEvent = new Map<String,Object>{'ToSequence' => 'Test'};
        List<Map<String,Object>> inputEvents = new List<Map<String,Object>>{
            inputEvent,
            inputEvent,
            inputEvent,
            inputEvent,
            inputEvent,
            inputEvent,
            inputEvent,
            inputEvent,
            inputEvent
        };
        
        Test.startTest();
        Job job = new Job(inputEvents);
        System.enqueueJob(job);
        Test.stopTest();
        
        List<Message__c> messages = [SELECT Id, Event__c FROM Message__c];
        BrokerImplementation impl = new BrokerImplementation();
        
        //act (start up big query locator)
        Database.QueryLocatorIterator iterator = impl.start(null).iterator();
        List<SObject> records = new List<Sobject>();
        while (iterator.hasNext()) records.add(iterator.next());
        
        //assert
        Integer expectedSize = 50;
        Integer actualSize = records.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
        
        //act (persist none and mark as many as he can fit within remaining contexts)
        impl.execute(null, new List<SObject>());
        
        //assert
        Integer expectedMarked = 5;
        Integer actualMarked = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Started'];
        System.assertEquals(expectedMarked, actualMarked, 'Wrong marked.');
        
        //act (execute the marked guys and move them out of property)
        impl.execute(null, new List<SObject>());
        
        //assert
        Integer expectedPersistable = 10; //5 inputs 5 outputs (unless there were exceptions!)
        Integer actualPersistable = impl.Messages.size();
        System.assertEquals(expectedPersistable, actualPersistable, 'Wrong persistable.');
        
        //act (persist previous and mark as many as he can fit within remaining contexts)
        impl.execute(null, new List<SObject>());
        
        //assert
        expectedMarked = 4;
        actualMarked = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Started'];
        System.assertEquals(expectedMarked, actualMarked, 'Wrong marked.');
        
        //act (execute the marked guys and move them out of property)
        impl.execute(null, new List<SObject>());
        
        //assert
        expectedPersistable = 8; //4 inputs 4 outputs (unless there were exceptions!)
        actualPersistable = impl.Messages.size();
        System.assertEquals(expectedPersistable, actualPersistable, 'Wrong persistable.');
        
        //act (persist previous and mark as many as he can fit within remaining contexts)
        impl.execute(null, new List<SObject>());
        
        //assert
        expectedMarked = 9;
        actualMarked = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Started'];
        System.assertEquals(expectedMarked, actualMarked, 'Wrong marked.');
        
        //act (execute the marked guys and move them out of property)
        impl.execute(null, new List<SObject>());
        
        //assert
        expectedPersistable = 9; //9 inputs 0 outputs
        actualPersistable = impl.Messages.size();
        System.assertEquals(expectedPersistable, actualPersistable, 'Wrong persistable.');
    }

    static testmethod void testMarkAndExecuteAndDoneConditionAbortsJobAtEnd() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        //arrange steps
        Step__c step = SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
        
        //arrange input
        Map<String,Object> inputEvent = new Map<String,Object> {
            'ToSequence' => 'Test'
        };
        
        //arrange message
        Test.startTest();
        Job job = new Job(inputEvent);
        System.enqueueJob(job);
        Test.stopTest();
        
        //act (enqueue)
        BrokerImplementation impl = new BrokerImplementation();
        
        //assert
        Integer expectedCount = 1;
        Integer actualCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Buffered'];
        System.assertEquals(expectedCount, actualCount, 'Wrong count.');
        
        //act (persist any and mark as many as he can fit within remaining contexts)
        impl.execute(null, new List<SObject>());
        
        //assert
        expectedCount = 1;
        actualCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Started'];
        System.assertEquals(expectedCount, actualCount, 'Message should be marked.');
        
        //act (execute the marked guys and move them out of property)
        impl.execute(null, new List<SObject>());
        
        //assert
        Integer expectedPersistable = 1; //1 input 0 outputs (terminate)
        Integer actualPersistable = impl.Messages.size();
        System.assertEquals(expectedCount, actualCount, 'Wrong persistable.');
        
        //act (handing ANY context causes abort NEXT via isLastContext)
        impl.execute(new MockContext(), new List<SObject>());
        
        //assert
        expectedPersistable = 0; //nothing to mark
        actualPersistable = impl.Messages.size();
        System.assertEquals(expectedCount, actualCount, 'Wrong persistable.');
        
        try {
            //act (stage should be abort)
            impl.execute(new MockContext(), new List<SObject>());
            System.assert(false, 'Line above should throw exception.');
        } catch (StringException e) {
            //assert that JOB IS ABORTED
            String expectedMessage = 'Job does not exist or is already aborted.';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage, 'Wrong message');
        }
    }

    static testmethod void testMarkLimitedToTotalPotentialMarksWhenBufferedMessagesGtTotalPotentialMarks() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        //arrange steps
        Step__c step = SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
        
        //arrange input
        Map<String,Object> inputEvent1 = new Map<String,Object> {
            'ToSequence' => 'Test'
        };
        
        Map<String,Object> inputEvent2 = new Map<String,Object> {
            'ToSequence' => 'Test'
        };
        
        Map<String,Object> inputEvent3 = new Map<String,Object> {
            'ToSequence' => 'Test'
        };
        
        //arrange messages
        Test.startTest();
        
        Job job1 = new Job(inputEvent1);
        System.enqueueJob(job1);
        
        Job job2 = new Job(inputEvent2);
        System.enqueueJob(job2);
        
        Job job3 = new Job(inputEvent3);
        System.enqueueJob(job3);
        
        Test.stopTest();
        
        //arrange
        Integer totalPotentialMarks = 3; // Less than Buffered Messages Count
        
        
        //arrange resolution
        BrokerImplementation impl = new BrokerImplementation();
        Integer actualBufferedCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Buffered'];
        
        //act
        List<SObject> scopes = new List<SObject>();
        impl.execute(null, scopes);
        
        //assemble
        Integer actualCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Started'];
        
        //assert
        System.assert(actualBufferedCount > 0, 'Buffered Messages should be greater than zero');
        Integer expectedCount = (totalPotentialMarks > actualBufferedCount) ? actualBufferedCount : totalPotentialMarks;
        System.assertEquals(expectedCount, actualCount, 'Message should be started.');
    }

    static testmethod void testMarkLimitedToTotalBufferedMessagesWhenTotalPotentialMarksGtTotaBufferedMessagesCount() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        //arrange steps
        Step__c step = SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
        
        //arrange input
        Map<String,Object> inputEvent1 = new Map<String,Object> {
            'ToSequence' => 'Test'
        };
        
        Map<String,Object> inputEvent2 = new Map<String,Object> {
            'ToSequence' => 'Test'
        };
        
        Map<String,Object> inputEvent3 = new Map<String,Object> {
            'ToSequence' => 'Test'
        };
        
        //arrange messages
        Test.startTest();
        
        Job job1 = new Job(inputEvent1);
        System.enqueueJob(job1);
        
        Job job2 = new Job(inputEvent2);
        System.enqueueJob(job2);
        
        Job job3 = new Job(inputEvent3);
        System.enqueueJob(job3);
        
        Test.stopTest();
        
        //arrange
        Integer totalPotentialMarks = 4;  // Greater than Buffered Messages Count

        //arrange resolution
        BrokerImplementation impl = new BrokerImplementation();
        Integer actualBufferedCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Buffered'];
        
        //act
        List<SObject> scopes = new List<SObject>();
        impl.execute(null, scopes);
        
        //assemble
        Integer actualCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Started'];
        
        //assert
        System.assert(actualBufferedCount > 0, 'Buffered Messages should be greater than zero');
        Integer expectedCount = (totalPotentialMarks > actualBufferedCount) ? actualBufferedCount : totalPotentialMarks;
        System.assertEquals(expectedCount, actualCount, 'Message should be started.');
    }
    
    public class MockContext implements Database.BatchableContext {
        public Id getJobId() {return '707000000000000AAA';}
        public Id getChildJobId() {return '707000000000000AAA';}
    }
    
    static testmethod void testPanicConditionAbortsJob() {
        //arrange
        BrokerImplementation impl = new BrokerImplementation();
        
        try {
            //act, null should cause panic
            impl.NextStage = null;
            impl.execute(new MockContext(), new List<SObject>());
            System.assert(false, 'Line above should throw exception.');
        } catch (Broker.ServiceException e) {
            //assert
            String expectedMessage = 'Broker Panic. Unexpected stage: null';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage, 'Wrong message.');
        }
        
        //stage property should still be null
        
        try {
            //act (stage should be abort)
            impl.execute(new MockContext(), new List<SObject>());
            System.assert(false, 'Line above should throw exception.');
        } catch (StringException e) {
            //assert that JOB IS ABORTED
            String expectedMessage = 'Job does not exist or is already aborted.';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage, 'Wrong message');
        }
    }
    
    public class FinishDoesPersist {
        void callout(Map<String,Object> event) {}
        List<Map<String,Object>> execute(Map<String,Object> event) {return null;}
    }
    
    public class FinishDoesPersistSummary extends ApexClassModel.Summary {
        Integer Limits = 1;
    }
    
    //for #991 very last Execute should get Persisted
    static testmethod void testAllContextsDoneOk() {
        //arrange broker
        BrokerImplementation impl = new BrokerImplementation();
        
        //arrange inputs (25 messages, 1 mark and 1 execute for each, aligns with 50 contexts)
        List<Map<String,Object>> events = new List<Map<String,Object>>();
        for (Integer i = 0; i < 25; i++) events.add(new Map<String,Object>{'ToService' => FinishDoesPersist.class.getName()});
        
        //arrange messages
        Test.startTest();
        Job job = new Job(events);
        System.enqueueJob(job);
        Test.stopTest();
        
        //act
        impl.start(null);
        
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        impl.execute(null, new List<SObject>());
        
        impl.finish(null);
        
        //assert
        Integer expectedCount = 25;
        Integer actualCount = [SELECT COUNT() FROM Message__c];
        System.assertEquals(expectedCount, actualCount, 'Wrong count.');
    }
    
}