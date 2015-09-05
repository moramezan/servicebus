@IsTest public class BrokerTest { //formerly FailureProcess
    

    /**
     * Synchronous Broker is used inside of unit tests
     * to traverse sequences with multiple steps without
     * the "single execute" limit of Database.Batchable
     *
     * Alternatively we can use it to just call individual
     * broker method implementations like mark() and execute()
     * without actually starting or running the Broker itself
     */
    @TestVisible static private Boolean DidSynchronousBrokerRun = false;
    public class SynchronousBroker extends Broker {
        
        override public void runImpl() {
            //LOCATE
            List<Message__c> inputMessages = this.locateMarkableWork();
            
            //MARK
            this.mark(inputMessages);
            
            //EXECUTE
            List<Message__c> outputMessages = new List<Message__c>();
            this.execute(inputMessages, outputMessages);
            DidSynchronousBrokerRun = true;
            
            //PERSIST
            List<Message__c> inputAndOutputMessages = new List<Message__c>();
            inputAndOutputMessages.addAll(inputMessages);
            inputAndOutputMessages.addAll(outputMessages);
            Broker.persist(inputAndOutputMessages); //#782
            
            super.run();
        }
        
    }

    static testmethod void testChunkingMarkFindsMultipleWork() {
        //arrange processes and sequence and steps
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        Step__c wiretapStep = SequenceModel.fromName(sequence.Name).appendStep(Wiretap.class);
        Step__c terminateStep = SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
        
        //arrange messages
        Map<String,Object> inputEvent = new Map<String,Object>{'ToSequence' => 'Test'};
        
        List<Map<String,Object>> inputEvents = new List<Map<String,Object>>{
            inputEvent.clone(),
            inputEvent.clone(),
            inputEvent.clone(),
            inputEvent.clone(),
            inputEvent.clone(),
            inputEvent.clone(),
            inputEvent.clone(),
            inputEvent.clone(),
            inputEvent.clone()
        };
        
        Test.startTest();
        Job job = new Job(inputEvents);
        System.enqueueJob(job);
        Test.stopTest();
        
        //act
        List<Message__c> records = Broker.impl().locateMarkableWork();
        
        //assemble
        ApexClassModel.Summary summary = new ApexClassModel.Summary(Wiretap.class);
        
        //assert
        Integer expectedLimits = 5;
        Integer actualLimits = summary.Limits;
        System.assertEquals(expectedLimits, actualLimits, 'Wiretap should have meta limits of five.');
        
        Integer expectedSize = 5;
        Integer actualSize = records.size();
        System.assertEquals(expectedSize, actualSize, 'Chunking mark should have found five.');
    }
    

    static testmethod void hopsExceededWillHaltStartedWithAppropriateMessageDetail() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'sequenceA');
        insert sequence;
        
        //arrange steps
        SequenceModel model = SequenceModel.fromId(sequence.Id);
        model.appendStep(Wiretap.class);
        model.appendStep(Terminate.class);
        
        //arrange inputs
        Test.startTest();
        Job job = new Job(sequence.Name, '00D000000000000AAA');
        System.enqueueJob(job);
        Test.stopTest();
        
        //assert
        Integer expectedBuffered = 1;
        Integer actualBuffered = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Buffered'];
        System.assertEquals(expectedBuffered, actualBuffered, 'Wrong count.');
        
        //act
        Broker.MaximumHops = 2;
        Broker.impl().run();
        
        //assert
        Integer expectedStarted = 1;
        Integer actualStarted = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Started'];
        System.assertEquals(expectedStarted, actualStarted, 'Wrong count.');
        
        //assemble
        Message__c message = [
            SELECT Id, Exception__c
            FROM Message__c
            WHERE Status__c = 'Started'
        ];
        
        //assert
        String expectedException = Broker.UserException.class.getName() + ': Maximum hops reached: 2';
        String actualException = message.Exception__c;
        System.assertEquals(expectedException, actualException, 'Wrong exception.');
    }
    
    static testmethod void testSufficientHopsExecutesOk() {
        //arrange broker
        Broker.MaximumHops = 2;
        
        //arrange message
        Test.startTest();
        Job job = new Job(new Map<String,Object>());
        System.enqueueJob(job);
        Test.stopTest();
        
        //act
        Broker.impl().run();
        
        //assemble
        Message__c message = [SELECT Id, Exception__c FROM Message__c];
        
        //assert
        String unexpectedException = 'Maximum hops reached: 2';
        String actualException = message.Exception__c;
        System.assertNotEquals(unexpectedException, actualException, 'Wrong exception.');
    }

    static testmethod void callingEnqueueSetsHops() {
        //arrange message
        Test.startTest();
        Job job = new Job(new Map<String,Object>()); //enqueue sets hops
        System.enqueueJob(job);
        Test.stopTest();
        
        //assemble
        Message__c message = [SELECT Id, Event__c, Exception__c FROM Message__c];
        Map<String,Object> outputEvent = (Map<String,Object>)Json.deserializeUntyped(message.Event__c);
        
        //assert
        Integer expectedHops = 1;
        Integer actualHops = (Integer)outputEvent.get('Hops');
        System.assertEquals(expectedHops, actualHops, 'Wrong hops.');
    }

    static testmethod void callingExecuteSetsMissingHops() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        //arrange steps
        SequenceModel.fromId(sequence.Id).appendStep(Wiretap.class);
        SequenceModel.fromId(sequence.Id).appendStep(Terminate.class);
        
        //arrange message
        Map<String,Object> event = new Map<String,Object>{'Route' => 'Test#1'};
        Message__c inputMessage = new Message__c(
            Event__c = Json.serialize(event)
        );
        insert inputMessage;
        
        //act
        List<Message__c> outputMessages = new List<Message__c>();
        Broker.impl().execute(new List<Message__c>{inputMessage}, outputMessages);
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = outputMessages.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
        
        //assemble
        Map<String,Object> outputEvent = (Map<String,Object>)Json.deserializeUntyped(outputMessages[0].Event__c);
        
        //assert
        Integer expectedHops = 1;
        Integer actualHops = (Integer)outputEvent.get('Hops');
        System.assertEquals(expectedHops, actualHops, 'Wrong hops.');
    }
    
    static testmethod void testTooManyHopsPreparesException() {
        //arrange broker
        Broker.MaximumHops = 1;
        
        //arrange message
        Test.startTest();
        Job job = new Job(new Map<String,Object>());
        System.enqueueJob(job);
        Test.stopTest();
        
        //act
        Broker.impl().run();
        
        //assemble
        Message__c message = [SELECT Id, Exception__c FROM Message__c];
        
        //assert
        String expectedException = Broker.UserException.class.getName() + ': Maximum hops reached: 1';
        String actualException = message.Exception__c;
        System.assertEquals(expectedException, actualException, 'Wrong exception.');
    }
    
    
    static testmethod void canCorrectlyIncrementAndPersistMessages() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        //arrange steps
        SequenceModel model = SequenceModel.fromId(sequence.Id);
        model.appendStep(Wiretap.class);
        model.appendStep(Wiretap.class);
        model.appendStep(Terminate.class);
        
        Map<String,Object> event1 = new Map<String,Object>{'Route' => 'Test#1'};
        Map<String,Object> event2 = new Map<String,Object>{'Route' => 'Test#2'};
        List<Message__c> inputMessages = new List<Message__c>{
            new Message__c(Event__c = Json.serialize(event1)),
            new Message__c(Event__c = Json.serialize(event2))
        };
        
        //arranges messages
        Broker impl = Broker.impl();
        List<Message__c> outputMessages = new List<Message__c>();
        impl.execute(inputMessages, outputMessages);
        
        //act (performs increment)
        List<Message__c> inputAndOutputMessages = new List<Message__c>();
        inputAndOutputMessages.addAll(inputMessages);
        inputAndOutputMessages.addAll(outputMessages);
        Broker.persist(inputAndOutputMessages);
        
        //assert
        Integer expectedSize = 2;
        Integer actualSize = outputMessages.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');

        //arrange
        Map<String,Object> outputEventA = (Map<String,Object>)Json.deserializeUntyped(outputMessages[0].Event__c); //woops, this fails sometimes
        Map<String,Object> outputEventB = (Map<String,Object>)Json.deserializeUntyped(outputMessages[1].Event__c); //0/1 seems non deterministic

        String expectedPositionA = '2';
        String actualPositionA = ((String)outputEventA.get('Route')).substringAfter('#');
        System.assertEquals(expectedPositionA, actualPositionA, 'Wrong position A.');

        String expectedPositionB = '3';
        String actualPositionB = ((String)outputEventB.get('Route')).substringAfter('#');
        System.assertEquals(expectedPositionB, actualPositionB, 'Wrong position B.');
        
        //assert
        Integer expectedCount = 4;
        Integer actualCount = [SELECT COUNT() FROM Message__c];
        System.assertEquals(expectedCount, actualCount, 'Wrong count.');
    }
    
    static testmethod void testLocatorMarksCorrectNumberOfMessages() {
        //arrange
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        Step__c terminateStep = SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
        
        List<Map<String,Object>> inputEvents = new List<Map<String,Object>>{
            new Map<String,Object>{'ToSequence' => 'Test'},
            new Map<String,Object>{'ToSequence' => 'Test'},
            new Map<String,Object>{'ToSequence' => 'Test'}
        };
        
        Test.startTest();
        Job job = new Job(inputEvents);
        System.enqueueJob(job);
        Test.stopTest();
        
        //act
        Broker impl = Broker.impl();
        
        //MARK
        List<Message__c> messages = impl.locateMarkableWork();
        
        //assert
        Integer actualCount = messages.size();
        Integer expectedCount = 3;
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testmethod void testLocatorOnlyMarksNonStartedWork() {
        //arrange
        insert new List<Message__c>{
            new Message__c(Status__c = 'Started'),
            new Message__c(Status__c = 'Started')
        };
    
        //act
        List<Message__c> messages = Broker.impl().locateMarkableWork();
        
        //assert
        Integer expectedCount = 0;
        Integer actualCount = messages.size();
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testmethod void testLocatorReturnsOnlyBufferedWork() {
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        Step__c terminateStep = SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
        
        Map<String,Object> event = new Map<String,Object>{'Route' => 'Test#1'};
        
        //arrange fucked messages
        insert new List<Message__c>{
            new Message__c(Status__c = 'Started', Event__c = Json.serialize(event)),
            new Message__c(Status__c = 'Started', Event__c = Json.serialize(event))
        };
        
        //arrange Buffered messages
        insert new List<Message__c>{
            new Message__c(Status__c = 'Buffered', Event__c = Json.serialize(event)),
            new Message__c(Status__c = 'Buffered', Event__c = Json.serialize(event))
        };
        
        //act
        Broker impl = Broker.impl();
        
        //MARK
        List<Message__c> messages = impl.locateMarkableWork();
        
        // assert
        Integer expectedCount = 2;
        Integer actualCount = messages.size();
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testmethod void callingEnqueueSuccessfullyCallEnqueueImpAndCreatesDocument() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        //arrange steps
        SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
        
        //assert
        Integer expectedCountBefore = 0;
        Integer actualCountBefore = [SELECT COUNT() FROM Document];
        System.assertEquals(expectedCountBefore, actualCountBefore, 'Wrong count before.');
        
        //act (this calls blob enqueue signature that does inserts a document)
        Test.startTest();
        Job job = new Job('TestSequence', Blob.valueOf('PDF'));
        System.enqueueJob(job);
        Test.stopTest();
        
        //assert
        Integer expectedCountAfter = 1;
        Integer actualCountAfter = [SELECT COUNT() FROM Document];
        System.assertEquals(expectedCountAfter, actualCountAfter, 'Wrong count after.');
    }
    
    static testmethod void callingRestartSuccessfullyCallsrunImpl() {
        //arrange
        Test.startTest();
        Job job = new Job('Test', '00D000000000000AAA');
        System.enqueueJob(job);
        Test.stopTest();
        
        //assert
        System.assert(!DidSynchronousBrokerRun, 'Wrong flag before.');
        
        //act
        Broker.impl().run();
        
        //assert
        System.assert(DidSynchronousBrokerRun, 'Wrong flag after.');
        
    }

    
    // Bug with Salesforce:
    // We cannot legitimately test for recycle bin purges - See Andy Fawcett's stackexchange comment:
    // http://salesforce.stackexchange.com/questions/27180/database-emptyrecyclebin-exhibits-unexpected-behaviour
    
    // TODO - Test Fails
    //        Assume it will be fixed when deailing with Issue "migrate chunking logic into abstract Broker #636"
    // Method Name      testMissingPositionThrowsExpectedException
    // Error Message    System.AssertException: Assertion Failed: Message cannot have a null process.
    // Stack Trace      Class.BrokerTest.testMissingPositionThrowsExpectedException: line 680, column 1
    static testmethod void testMissingPositionThrowsExpectedException() {
        //arrange input
        Map<String,Object> inputEvent = new Map<String,Object>{'c__Not_Sequence_Or_Process' => 1};
        
        //arrange message
        Test.startTest();
        Job job = new Job(inputEvent);
        System.enqueueJob(job);
        Test.stopTest();
        
        //arrange
        List<Message__c> messages = [SELECT Id, Event__c FROM Message__c];
        
        //arrange broker
        Broker impl = Broker.impl();
        
        String actualMessage;
        
        //act
        impl.execute(messages, new List<Message__c>());
        
        //assemble
        actualMessage = messages[0].Exception__c;
        
        //assert
        String expectedMessage = Broker.UserException.class.getName() + ': Message has no route: ' + messages[0].Id;
        System.assertEquals(expectedMessage, actualMessage, 'Wrong exception message.');
    }
    
    static testmethod void testNoStepThrowsQueryException() {
        //arrange input (note there is no Step__c in database!)
        Map<String,Object> inputEvent = new Map<String,Object>{
            'ToSequence' => 'Test'
        };
        
        //arrange message
        Test.startTest();
        Job job = new Job(inputEvent);
        System.enqueueJob(job);
        Test.stopTest();
        
        //act
        Broker.impl().run();
        
        //assemble
        Message__c message = [SELECT Id, Exception__c FROM Message__c];
        
        //assert
        String expectedException = Broker.UserException.class.getName() + ': Could not resolve message route: Test#1';
        String actualException = message.Exception__c;
        System.assertEquals(expectedException, actualException, 'Wrong message.');
    }
    
    static testmethod void testProcessWithoutClassThrowsExpectedException() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        //arrange steps
        Step__c step = SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
        step.ApexClassName__c = 'lalala';
        update step;
        
        //arrange message
        Test.startTest();
        Job job = new Job(sequence.Name, '00D000000000000AAA');
        System.enqueueJob(job);
        Test.stopTest();
        
        //act
        Broker.impl().run();
        
        //assemble
        Message__c message = [SELECT Id, Cause__c, Exception__c FROM Message__c];
        
        //assert
        String actualMessage = message.Exception__c;
        String expectedMessage = Broker.UserException.class.getName() + ': Class is invalid or not visible: lalala';
        System.assertEquals(expectedMessage, actualMessage, 'Wrong message detail.');
    }
    
    static testmethod void canGenerateUniqueIds() {
        // arrange
        Integer uniqueTotal = 20000;
        Integer len = 10; // for len=5, Expected: 10000, Actual: 9944
        
        // act
        Set<String> uniqueIds =  new Set<String>();
        Integer count = 1;
        while (count <= uniqueTotal) {
            uniqueIds.add(Job.uuidVersionFour());
            count++;
        }

        // assert
        Integer expectedSize = uniqueTotal;
        Integer actualSize = uniqueIds.size();
        System.assertEquals(expectedSize, actualSize);
    }
    
    static testmethod void callingEnqueueWhenBrokerIsPausedQueuesMessageWithStatusPaused() {
        //arrange broker
        insert new BrokerSetting__c(IsPaused__c = true);
        Boolean isPaused =  true;
        
        //act
        Test.startTest();
        Job job = new Job('Test', '00D000000000000AAA');
        System.enqueueJob(job);
        Test.stopTest();
        
        //assemble
        Integer expectedCount = 1;
        Integer actualCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Paused'];
        System.assertEquals(expectedCount, actualCount, 'Wrong size.');
    }

    static testmethod void callingEnqueueWhenBrokerIsNotPausedProcessesMessages() {
        //arrange broker
        insert new BrokerSetting__c(IsPaused__c = false);
        
        //act
        Test.startTest();
        Job job = new Job('Test', '00D000000000000AAA');
        System.enqueueJob(job);
        Test.stopTest();
        
        Integer expectedCount = 1;
        Integer actualCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Buffered'];
        System.assertEquals(expectedCount, actualCount, 'Wrong count.');
    }
 
 
    // TODO - Test Fails
    //        Assume it will be fixed when deailing with Issue "migrate chunking logic into abstract Broker #636"
    // Method Name      canFailureToCorrectlyResolveAndPersistMessagesPersistsExpectedError
    // Error Message    System.AssertException: Assertion Failed: Wrong message: Expected: Step unqueryable, eg bad sequence
    //                  name, position, missing terminate., Actual: Message cannot have a null process.
    // Stack Trace      Class.BrokerTest.canFailureToCorrectlyResolveAndPersistMessagesPersistsExpectedError: line 961, column 1
    // #697 is exercised by this test!
    static testmethod void canFailureToCorrectlyResolveAndPersistMessagesPersistsExpectedError() {
        // arrange
        String sequenceNameA = 'Test';
        Sequence__c sequenceA = new Sequence__c(Name = sequenceNameA);
        insert sequenceA;


        Integer positionA1 = 1;
        Integer positionA2 = 2;
        Integer positionA3 = 3;
        // deleted - implying a resolution issue
        Integer positionA5 = 5;
        Integer positionA6 = 6;

        Step__c stepA1 = SequenceModel.fromName(sequenceA.Name).appendStep(Wiretap.class);
        Step__c stepA2 = SequenceModel.fromName(sequenceA.Name).appendStep(Wiretap.class);
        Step__c stepA3 = SequenceModel.fromName(sequenceA.Name).appendStep(Wiretap.class);
        Step__c issue =  SequenceModel.fromName(sequenceA.Name).appendStep(Wiretap.class); // deleted - implying a resolution issue
        Step__c stepA5 = SequenceModel.fromName(sequenceA.Name).appendStep(Wiretap.class);
        Step__c stepA6 = SequenceModel.fromName(sequenceA.Name).appendStep(Terminate.class);
        
        delete issue;
        
        //act
        Test.startTest();
        Job job = new Job(sequenceNameA, '00D000000000000AAA');
        System.enqueueJob(job);
        Test.stopTest();
        
        //act
        Broker.impl().run();
        
        //assert
        Integer expectedSuccessCount = 3;
        Integer actualSuccessCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Completed'];
        System.assertEquals(expectedSuccessCount, actualSuccessCount, 'Wrong success count.');
        
        //assemble
        List<Message__c> messages = [
            SELECT Id, Name, Event__c, Status__c, Exception__c
            FROM Message__c
            WHERE Status__c = 'Started'
        ];
        
        //assert
        Integer expectedFailureCount = 1;
        Integer actualFailureCount = messages.size();
        System.assertEquals(expectedFailureCount, actualFailureCount, 'Wrong failure count.');
        
        String expectedException = Broker.UserException.class.getName() + ': Could not resolve message route: Test#4';
        String actualException = messages[0].Exception__c;
        System.assertEquals(expectedException, actualException, 'Wrong exception.');
    }
 
    static testMethod void callingEnqueueWithEventParametersIncludesAllEventParametersInMessage() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        //arrange steps
        SequenceModel model = SequenceModel.fromId(sequence.Id);
        model.appendStep(Terminate.class);
        
        //arrange input event
        DateTime timestamp = DateTime.newInstance(2014,12,15,13,11,07);
        Map<String,Object> inputEvent = new Map<String,Object>{
            'RecordId' => UserInfo.getUserId(),
            'ToSequence' => 'Test',
            'EntryPointTimestamp' => timestamp
        };
             
        //act
        new Job(inputEvent).execute(null);
        
        //assemble
        List<Message__c> messages = [
            SELECT Id, Event__c
            FROM Message__c
        ];
        
        //assert
        Integer expectedCount = 1;
        Integer actualCount = messages.size();
        System.assertEquals(expectedCount, actualCount, 'Wrong count.');
        
        //assemble
        Map<String,Object> actualEvent = (Map<String,Object>)Json.deserializeUntyped(messages[0].Event__c);
        
        DateTime expectedTimestamp = timestamp;
        DateTime actualTimestamp = (DateTime)Json.deserialize('"' + ((String)actualEvent.get('EntryPointTimestamp')) + '"', DateTime.class);
        System.assertEquals(expectedTimestamp, actualTimestamp);
    }

    static testMethod void callingExecuteWithoutMandatoryEventParametersInEventParametersCollectionThrowsException() {
        // arrange process, sequence, step
        String sequenceName = 'Test';
        Sequence__c sequence = new Sequence__c(Name = sequenceName);
        insert sequence;
        
        Step__c step = SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
  
        //arrange inputs
        Map<String,Object> input1 = new Map<String,Object>{'ToSequence' => 'Test'};
        Map<String,Object> input2 = new Map<String,Object>{'RecordId' => null};
  
        //arrange messages
        Test.startTest();
        Job job1 = new Job(input1);
        System.enqueueJob(job1);
        Job job2 = new Job(input2);
        System.enqueueJob(job2);
        Test.stopTest();
        
        //act
        List<Message__c> messages = [SELECT Id, Event__c FROM Message__c];
        Broker.impl().execute(messages, new List<Message__c>());
        
        //assert
        String expectedException = null;
        String actualException = messages[0].Exception__c;
        System.assertEquals(expectedException, actualException, 'Wrong exception 1.');
        
        expectedException = Broker.UserException.class.getName() + ': Message has no route: ' + messages[1].Id;
        actualException = messages[1].Exception__c;
        System.assertEquals(expectedException, actualException, 'Wrong exception 1.');
    }
    
    static testMethod void callingEnqueueAlwaysSetsInitiatingEventParameters() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        //arrange steps
        SequenceModel model = SequenceModel.fromId(sequence.Id);
        model.appendStep(Terminate.class);
        
        //act
        new Job(sequence.Name, '00D000000000000AAA').execute(null);
        
        //assemble
        List<Message__c> messages = [
            SELECT Id, Event__c
            FROM Message__c
            LIMIT 1
        ];
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = messages.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
        
        //assemble
        Map<String,Object> inputEvent = (Map<String,Object>)Json.deserializeUntyped(messages[0].Event__c);
        
        String unexpectedEntryPointUuid = null;
        String actualEntryPointUuid = (String)inputEvent.get('EntryPointUuid');
        System.assertNotEquals(unexpectedEntryPointUuid, actualEntryPointUuid, 'Wrong entry point uuid.');
        
        String expectedPosition = '1';
        String actualPosition = ((String)inputEvent.get('Route')).substringAfter('#');
        System.assertEquals(expectedPosition, actualPosition, 'Wrong position.');
        
        Id expectedEnqueueUserId = UserInfo.getUserId();
        Id actualEnqueueUserId = (Id)inputEvent.get('EnqueuedById');
        System.assertEquals(expectedEnqueueUserId, actualEnqueueUserId, 'Wrong enqueue user id.');
    }

    static testMethod void callingIsAllowedSessionIdReturnsExpectedValue() {
        //arrange
        String reflectorName01 = 'esb';       // good ns
        Id orgId01 = '00Dj0000000I44v';       // good org
        String reflectorName02 = 'whatever';  // bullshit ns
        Id orgId02 = '00Dj0000000I44v';       // good org
        String reflectorName03 = 'esb';       // good ns
        Id orgId03 = '00Dj0000000bull';       // bullshit org
        String reflectorName04 = 'whatever';  // bullshit ns
        Id orgId04 = '00Dj0000000bull';       // bullshit org
         
        //act
        Boolean actualFlag01 = Broker.isAllowedSessionId(reflectorName01, orgId01);
        Boolean actualFlag02 = Broker.isAllowedSessionId(reflectorName02, orgId02);
        Boolean actualFlag03 = Broker.isAllowedSessionId(reflectorName03, orgId03);
        Boolean actualFlag04 = Broker.isAllowedSessionId(reflectorName04, orgId04);
        
        //assert
        Boolean expectedFlag01 = true;
        Boolean expectedFlag02 = true;
        Boolean expectedFlag03 = true;
        Boolean expectedFlag04 = false;
        System.assertEquals(expectedFlag01, actualFlag01);
        System.assertEquals(expectedFlag02, actualFlag02);
        System.assertEquals(expectedFlag03, actualFlag03);
        System.assertEquals(expectedFlag04, actualFlag04);
    }
    
    @TestVisible public class ChunkErrorProcessException extends Exception {}
    
    public class ChunkErrorProcess extends ApexClassModel.Process {
        void callout(Map<String,Object> inputEvent) {}
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            Boolean isError = (Boolean)inputEvent.get('c__IsError');
            if (isError == true) throw new ChunkErrorProcessException('Test error');
            return new List<Map<String,Object>>{inputEvent.clone()}; //one message
        }
    }
    
    public class ChunkErrorProcessSummary {
        String Description = 'Does stuff in memory without side effects.';
        Integer Limits = 2;
    }
    
    static testmethod void testKamikazeChunkingDoesntTakeOutHisMates() {
        //arrange processes, sequence and steps
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        Step__c errorStep = SequenceModel.fromName(sequence.Name).appendStep(ChunkErrorProcess.class);
        Step__c terminateStep = SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
        
        //arrange broker implementation and params
        Map<String,Object> failureEvent = new Map<String,Object>{'c__IsError' => true, 'ToSequence' => 'Test'};
        Map<String,Object> successEvent = new Map<String,Object>{'c__IsError' => false, 'ToSequence' => 'Test'};
        List<Map<String,Object>> events = new List<Map<String,Object>>{failureEvent, successEvent};
        
        //arrange messages and broker
        Test.startTest();
        Job job = new Job(events);
        System.enqueueJob(job);
        Test.stopTest();
        
        List<Message__c> messages = [SELECT Id, Event__c FROM Message__c];
        Broker impl = Broker.impl();
        messages = impl.locateMarkableWork();
        
        //act
        List<Message__c> outputMessages = new List<Message__c>();
        impl.execute(messages, outputMessages);
        
        //assert #798 should only have one message
        Integer expectedCount = 1;
        Integer actualCount = outputMessages.size();
        System.assertEquals(expectedCount, actualCount);
        
    }
    
    /**
     * Sibling ID population...
     */
    public class FakeGate extends ApexClassModel.Process {
        void callout(Map<String,Object> inputEvent) {}
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            DidRun = true;
            SiblingIds = (Set<Id>)Json.deserialize(Json.serialize(inputEvent.get('SiblingIds')), Set<Id>.class);
            return new List<Map<String,Object>>();
        }
    }
    
    public class FakeGateSummary {
        String Description = 'fake gate';
        Integer Limits = 999;
    }
    
    static Boolean DidRun = false;
    static Set<Id> SiblingIds;
    
    static testmethod void testBrokerPopulatesSiblingIds() {
        //arrange event
        Map<String,Object> inputEvent = new Map<String,Object>{
            'Route' => FakeGate.class.getName()
        };
        
        //arrange messages
        List<Message__c> inputMessages = new List<Message__c>{
            new Message__c(Event__c = Json.serialize(inputEvent)),
            new Message__c(Event__c = Json.serialize(inputEvent))
        };
        insert inputMessages;
        
        //act
        Broker impl = Broker.impl();
        impl.mark(inputMessages);
        impl.execute(inputMessages, new List<Message__c>());
        if (!DidRun) System.assert(false, 'Process probably did not run.');
        System.assertEquals(null, inputMessages[0].Exception__c, 'Wrong exception.');
        
        //assert
        System.assert(SiblingIds.contains(inputMessages[0].Id), 'Message1 id missing.');
        System.assert(SiblingIds.contains(inputMessages[1].Id), 'Message2 id missing.');
    }
}