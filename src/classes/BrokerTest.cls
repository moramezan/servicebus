@IsTest class BrokerTest {
    
    @TestSetup static void testSetup() {
        //act
        new PostInstallHandler().onInstall(null);
        
        //assert
        System.assertNotEquals(null, Application__c.getOrgDefaults().Id, 'Wrong id.');
    }
    
    class MockJob implements System.Schedulable {
        public void execute(System.SchedulableContext context) {}
    }
    
    class BatchableContext implements Database.BatchableContext {
        Id jobId;
        public BatchableContext() {this.jobId = System.schedule('test', '0 0 * * * ?', new MockJob());}
        public Id getJobId() {return this.jobId;}
        public Id getChildJobId() {return this.jobId;}
    }
    
    class QueueableContext implements System.QueueableContext {
        Id jobId;
        public QueueableContext() {this.jobId = System.schedule('test', '0 0 * * * ?', new MockJob());}
        public Id getJobId() {return this.jobId;}
    }
    
    /**
     * Synchronous Broker is used inside of unit tests
     * to traverse sequences with multiple steps without
     * the "single execute" limit of Database.Batchable
     *
     * Alternatively we can use it to just call individual
     * broker method implementations like mark() and execute()
     * without actually starting or running the Broker itself
     */
    @TestVisible static Boolean DidSynchronousBrokerRun = false;
    public class SynchronousBroker extends Broker {
        
        @TestVisible List<Message__c> InputMessages = new List<Message__c>();
        @TestVisible List<Message__c> OutputMessages = new List<Message__c>();
        
        override public void run() {
            
            String slot = '0000';
            
            //MARK (or abort if nothing located)
            MessageSetModel model = MessageSetModel.locateMarkableWork();
            if (model.getRecords().isEmpty()) return;
            this.InputMessages = model.mark(slot);
            
            //EXECUTE
            this.OutputMessages = new MessageSetModel(this.InputMessages).execute(null); //EXECUTE
            DidSynchronousBrokerRun = true;
            
            //PERSIST
            if (this.OutputMessages != null) new MessageSetModel(this.InputMessages).persist(this.OutputMessages); //PERSIST
            
            //MORE
            if (![SELECT Id FROM Message__c WHERE Status__c = 'Buffered' LIMIT 1].isEmpty()) this.run();
            
        }
        
    }

    static testmethod void testChunkingMarkFindsMultipleWork() {
        //arrange services and sequence and steps
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        Step__c wiretapStep = SequenceModel.fromName(sequence.Name).appendStep(WiretapService.class.getName());
        Step__c terminateStep = SequenceModel.fromName(sequence.Name).appendStep(TerminateService.class.getName());
        
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
        Enqueue.invoke(inputEvents);
        Test.stopTest();
        
        //act
        List<Message__c> records = MessageSetModel.locateMarkableWork().getRecords();
        
        //assemble
        ApexClassModel.Definition definition = new ApexClassModel.Definition(WiretapService.class);
        
        //assert
        Integer expectedChunks = 5;
        Integer actualChunks = definition.Chunks;
        System.assertEquals(expectedChunks, actualChunks, 'Wiretap should have definition chunks of five.');
        
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
        model.appendStep(WiretapService.class.getName());
        model.appendStep(TerminateService.class.getName());
        
        //arrange inputs
        Test.startTest();
        Enqueue.invoke(new Map<String,Object>{'ToSequence' => '00D000000000000AAA'});
        Test.stopTest();
        
        //assert
        Integer expectedBuffered = 1;
        Integer actualBuffered = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Buffered'];
        System.assertEquals(expectedBuffered, actualBuffered, 'Wrong count.');
        
        //act
        Broker.MaximumHops = 1;
        Broker.impl().run();
        
        //assert
        Integer expectedStarted = 1;
        Integer actualStarted = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Started' ALL ROWS]; //#1114
        System.assertEquals(expectedStarted, actualStarted, 'Wrong count.');
        
        //assemble
        Message__c message = [
            SELECT Id, Exception__c
            FROM Message__c
            WHERE Status__c = 'Started'
        ];
        
        //assert
        String expectedException = Broker.ServiceException.class.getName() + ': Maximum hops reached: 1';
        String actualException = message.Exception__c;
        System.assertEquals(expectedException, actualException, 'Wrong exception.');
    }
    
    static testmethod void testSufficientHopsExecutesOk() {
        //arrange broker
        Broker.MaximumHops = 2;
        
        //arrange message
        Test.startTest();
        Enqueue.invoke(new Map<String,Object>{'ToService' => 'Test'});
        Test.stopTest();
        
        //act
        Broker.impl().run();
        
        //assemble
        Message__c message = [SELECT Id, Exception__c FROM Message__c ALL ROWS]; //#1114
        
        //assert
        String unexpectedException = 'Maximum hops reached: 2';
        String actualException = message.Exception__c;
        System.assertNotEquals(unexpectedException, actualException, 'Wrong exception.');
    }

    static testmethod void callingEnqueueSetsHops() {
        //arrange message
        Test.startTest();
        Enqueue.invoke(new Map<String,Object>{'ToService' => 'Test'}); //enqueue sets hops
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
        SequenceModel.fromId(sequence.Id).appendStep(WiretapService.class.getName());
        SequenceModel.fromId(sequence.Id).appendStep(TerminateService.class.getName());
        
        //arrange message
        Map<String,Object> event = new Map<String,Object>{'Route' => '1#Test#1'};
        Message__c inputMessage = new Message__c(
            Event__c = Json.serialize(event)
        );
        insert inputMessage;
        
        //act
        List<Message__c> outputMessages = new MessageSetModel(new List<Message__c>{inputMessage}).execute(null);
        
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
        Enqueue.invoke(new Map<String,Object>{'ToService' => 'Test'}); //enqueue sets hops
        Test.stopTest();
        
        //act
        Broker.impl().run();
        
        //assemble
        Message__c message = [SELECT Id, Exception__c FROM Message__c ALL ROWS]; //#1114
        
        //assert
        String expectedException = Broker.ServiceException.class.getName() + ': Maximum hops reached: 1';
        String actualException = message.Exception__c;
        System.assertEquals(expectedException, actualException, 'Wrong exception.');
    }
    
    
    static testmethod void canCorrectlyIncrementAndPersistMessages() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        //arrange steps
        SequenceModel model = SequenceModel.fromId(sequence.Id);
        model.appendStep(WiretapService.class.getName());
        model.appendStep(WiretapService.class.getName());
        model.appendStep(TerminateService.class.getName());
        
        Map<String,Object> event1 = new Map<String,Object>{'Route' => '1#Test#1'};
        Map<String,Object> event2 = new Map<String,Object>{'Route' => '1#Test#2'};
        List<Message__c> inputMessages = new List<Message__c>{
            new Message__c(Event__c = Json.serialize(event1)),
            new Message__c(Event__c = Json.serialize(event2))
        };
        
        //arranges messages
        insert inputMessages;
        new MessageSetModel(inputMessages).mark('0000');
        List<Message__c> outputMessages = new MessageSetModel(inputMessages).execute(null);
        
        //act (performs increment)
        new MessageSetModel(inputMessages).persist(outputMessages);
        
        //assert
        Integer expectedSize = 2;
        Integer actualSize = outputMessages.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');

        //arrange
        Map<String,Object> outputEventA = (Map<String,Object>)Json.deserializeUntyped(outputMessages[0].Event__c); //woops, this fails sometimes
        Map<String,Object> outputEventB = (Map<String,Object>)Json.deserializeUntyped(outputMessages[1].Event__c); //0/1 seems non deterministic

        String expectedPositionA = '2';
        String actualPositionA = ((String)outputEventA.get('Route')).substringAfterLast('#');
        System.assertEquals(expectedPositionA, actualPositionA, 'Wrong position A.');

        String expectedPositionB = '3';
        String actualPositionB = ((String)outputEventB.get('Route')).substringAfterLast('#');
        System.assertEquals(expectedPositionB, actualPositionB, 'Wrong position B.');
        
        //assert
        Integer expectedCount = 4;
        Integer actualCount = [SELECT COUNT() FROM Message__c ALL ROWS]; //#1114
        System.assertEquals(expectedCount, actualCount, 'Wrong count.');
    }
    
    static testmethod void testLocatorMarksCorrectNumberOfMessages() {
        //arrange
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        Step__c terminateStep = SequenceModel.fromName(sequence.Name).appendStep(TerminateService.class.getName());
        
        List<Map<String,Object>> inputEvents = new List<Map<String,Object>>{
            new Map<String,Object>{'ToSequence' => 'Test'},
            new Map<String,Object>{'ToSequence' => 'Test'},
            new Map<String,Object>{'ToSequence' => 'Test'}
        };
        
        Test.startTest();
        Enqueue.invoke(inputEvents);
        Test.stopTest();
        
        //act
        List<Message__c> messages = MessageSetModel.locateMarkableWork().getRecords();
        
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
        List<Message__c> messages = MessageSetModel.locateMarkableWork().getRecords();
        
        //assert
        Integer expectedCount = 0;
        Integer actualCount = messages.size();
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testmethod void testLocatorReturnsOnlyBufferedWork() {
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        Step__c terminateStep = SequenceModel.fromName(sequence.Name).appendStep(TerminateService.class.getName());
        
        Map<String,Object> event = new Map<String,Object>{'Route' => '1#Test#1'};
        
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
        List<Message__c> messages = MessageSetModel.locateMarkableWork().getRecords();
        
        // assert
        Integer expectedCount = 2;
        Integer actualCount = messages.size();
        System.assertEquals(expectedCount, actualCount);
    }
    
    /*static testmethod void callingEnqueueSuccessfullyCallEnqueueImpAndCreatesDocument() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        //arrange steps
        SequenceModel.fromName(sequence.Name).appendStep(TerminateService.class.getName());
        
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
    }*/
    
    static testmethod void callingRestartSuccessfullyCallsrunImpl() {
        //arrange
        Test.startTest();
        Enqueue.invoke(new Map<String,Object>{'ToSequence' => 'Test'});
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
    // Error Message    System.AssertException: Assertion Failed: Message cannot have a null service.
    // Stack Trace      Class.BrokerTest.testMissingPositionThrowsExpectedException: line 680, column 1
    static testmethod void testMissingPositionThrowsExpectedException() {
        //arrange input
        Map<String,Object> inputEvent = new Map<String,Object>{'ToSequence' => '', 'c:Not_Sequence_Or_Service' => 1};
        
        //arrange message
        Test.startTest();
        Enqueue.invoke(inputEvent);
        Test.stopTest();
        
        //arrange
        List<Message__c> messages = [SELECT Id, Event__c FROM Message__c];
        
        //act
        new MessageSetModel(messages).execute(null);
        
        //assemble
        
        //assert
        String expectedMessage = ApexClassModel.ModelException.class.getName() + ': Could not resolve route: 1##1';
        String actualMessage = messages[0].Exception__c;
        System.assertEquals(expectedMessage, actualMessage, 'Wrong exception message.');
    }
    
    static testmethod void testNoStepThrowsQueryException() {
        //arrange input (note there is no Step__c in database!)
        Map<String,Object> inputEvent = new Map<String,Object>{
            'ToSequence' => 'Test'
        };
        
        //arrange message
        Test.startTest();
        Enqueue.invoke(inputEvent);
        Test.stopTest();
        
        //act
        Broker.impl().run();
        
        //assemble
        Message__c message = [SELECT Id, Exception__c FROM Message__c ALL ROWS]; //#1114
        
        //assert
        String expectedException = ApexClassModel.ModelException.class.getName() + ': Could not resolve route: 1#Test#1';
        String actualException = message.Exception__c;
        System.assertEquals(expectedException, actualException, 'Wrong message.');
    }
    
    static testmethod void testServiceWithoutClassThrowsExpectedException() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        //arrange steps
        Step__c step = SequenceModel.fromName(sequence.Name).appendStep(TerminateService.class.getName());
        step.ApexTypeName__c = 'lalala';
        update step;
        
        //arrange message
        Test.startTest();
        Enqueue.invoke(new Map<String,Object>{'ToSequence' => sequence.Name});
        Test.stopTest();
        
        //act
        Broker.impl().run();
        
        //assemble
        Message__c message = [SELECT Id, Cause__c, Exception__c FROM Message__c ALL ROWS]; //#1114
        
        //assert
        String actualMessage = message.Exception__c;
        String expectedMessage = ApexClassModel.ModelException.class.getName() + ': Class is invalid or not visible: lalala';
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
            uniqueIds.add(Enqueue.uuidVersionFour());
            count++;
        }

        // assert
        Integer expectedSize = uniqueTotal;
        Integer actualSize = uniqueIds.size();
        System.assertEquals(expectedSize, actualSize);
    }
    
    static testmethod void callingEnqueueWhenBrokerIsPausedQueuesMessageWithStatusPaused() {
        //arrange broker
        Application__c application = Application__c.getOrgDefaults();
        application.BrokerIsPaused__c = true;
        upsert application;
        
        //act
        Test.startTest();
        Enqueue.invoke(new Map<String,Object>{'ToSequence' => 'Test'});
        Test.stopTest();
        
        //assemble
        Integer expectedCount = 1;
        Integer actualCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Paused'];
        System.assertEquals(expectedCount, actualCount, 'Wrong size.');
    }

    static testmethod void callingEnqueueWhenBrokerIsNotPausedWorksOnMessages() {
        //arrange broker
        Application__c application = Application__c.getOrgDefaults();
        application.BrokerIsPaused__c = false;
        upsert application;
        
        //act
        Test.startTest();
        Enqueue.invoke(new Map<String,Object>{'ToSequence' => 'Test'});
        Test.stopTest();
        
        Integer expectedCount = 1;
        Integer actualCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Buffered'];
        System.assertEquals(expectedCount, actualCount, 'Wrong count.');
    }
 
 
    // TODO - Test Fails
    //        Assume it will be fixed when deailing with Issue "migrate chunking logic into abstract Broker #636"
    // Method Name      canFailureToCorrectlyResolveAndPersistMessagesPersistsExpectedError
    // Error Message    System.AssertException: Assertion Failed: Wrong message: Expected: Step unqueryable, eg bad sequence
    //                  name, position, missing terminate., Actual: Message cannot have a null service.
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

        Step__c stepA1 = SequenceModel.fromName(sequenceA.Name).appendStep(WiretapService.class.getName());
        Step__c stepA2 = SequenceModel.fromName(sequenceA.Name).appendStep(WiretapService.class.getName());
        Step__c stepA3 = SequenceModel.fromName(sequenceA.Name).appendStep(WiretapService.class.getName());
        Step__c issue =  SequenceModel.fromName(sequenceA.Name).appendStep(WiretapService.class.getName()); // deleted - implying a resolution issue
        Step__c stepA5 = SequenceModel.fromName(sequenceA.Name).appendStep(WiretapService.class.getName());
        Step__c stepA6 = SequenceModel.fromName(sequenceA.Name).appendStep(TerminateService.class.getName());
        
        delete issue;
        
        //act
        Test.startTest();
        Enqueue.invoke(new Map<String,Object>{'ToSequence' => sequenceNameA});
        Test.stopTest();
        
        //act
        Broker.impl().run();
        
        //assert
        Integer expectedSuccessCount = 3;
        Integer actualSuccessCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Completed' ALL ROWS]; //#1114
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
        
        String expectedException = ApexClassModel.ModelException.class.getName() + ': Could not resolve route: 1#Test#4';
        String actualException = messages[0].Exception__c;
        System.assertEquals(expectedException, actualException, 'Wrong exception.');
    }
 
    static testMethod void callingEnqueueWithEventParametersIncludesAllEventParametersInMessage() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        //arrange steps
        SequenceModel model = SequenceModel.fromId(sequence.Id);
        model.appendStep(TerminateService.class.getName());
        
        //arrange input event
        DateTime timestamp = DateTime.newInstance(2014,12,15,13,11,07);
        Map<String,Object> inputEvent = new Map<String,Object>{
            'RecordId' => UserInfo.getUserId(),
            'ToSequence' => 'Test',
            'EntryPointTimestamp' => timestamp
        };
        
        //act
        Enqueue.invoke(inputEvent);
        
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

    //#1220 no unroutable messages
    /*static testMethod void callingExecuteWithoutMandatoryEventParametersInEventParametersCollectionThrowsException() {
        // arrange service, sequence, step
        String sequenceName = 'Test';
        Sequence__c sequence = new Sequence__c(Name = sequenceName);
        insert sequence;
        
        Step__c step = SequenceModel.fromName(sequence.Name).appendStep(TerminateService.class.getName());
  
        //arrange inputs
        Map<String,Object> input1 = new Map<String,Object>{'ToSequence' => 'Test'};
        Map<String,Object> input2 = new Map<String,Object>{'ToSequence' => 'Test', 'RecordId' => null};
  
        //arrange messages
        Test.startTest();
        Enqueue.invoke(input1);
        Enqueue.invoke(input2);
        Test.stopTest();
        
        //act
        List<Message__c> messages = [SELECT Id, Event__c FROM Message__c];
        new MessageSetModel(messages).execute(null);
        
        //assert
        String expectedException = null;
        String actualException = messages[0].Exception__c;
        System.assertEquals(expectedException, actualException, 'Wrong exception 1.');
        
        expectedException = ApexClassModel.ModelException.class.getName() + ': Route was null.';
        actualException = messages[1].Exception__c;
        System.assertEquals(expectedException, actualException, 'Wrong exception 1.');
    }*/
    
    static testMethod void callingEnqueueAlwaysSetsInitiatingEventParameters() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        //arrange steps
        SequenceModel model = SequenceModel.fromId(sequence.Id);
        model.appendStep(TerminateService.class.getName());
        
        //act
        Enqueue.invoke(new Map<String,Object>{'ToSequence' => sequence.Name});
        
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
        
        String unexpectedCorrelationUuid = null;
        String actualCorrelationUuid = (String)inputEvent.get('CorrelationUuid');
        System.assertNotEquals(unexpectedCorrelationUuid, actualCorrelationUuid, 'Wrong correlation uuid.');
        
        String expectedPosition = '1';
        String actualPosition = ((String)inputEvent.get('Route')).substringAfterLast('#');
        System.assertEquals(expectedPosition, actualPosition, 'Wrong position.');
        
        Id expectedEnqueueUserId = UserInfo.getUserId();
        Id actualEnqueueUserId = (Id)inputEvent.get('EnqueuedById');
        System.assertEquals(expectedEnqueueUserId, actualEnqueueUserId, 'Wrong enqueue user id.');
    }

    static testMethod void callingIsAllowedSessionIdReturnsExpectedValue() {
        //arrange
        String reflectorName01 = 'servicebus';       // good ns
        Id orgId01 = '00Dj0000000I44v';       // good org
        String reflectorName02 = 'whatever';  // bullshit ns
        Id orgId02 = '00Dj0000000I44v';       // good org
        String reflectorName03 = 'servicebus';       // good ns
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
    
    public class ChunkErrorService extends ApexClassModel.Service {
        void callout(Map<String,Object> inputEvent) {}
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            Boolean isError = (Boolean)inputEvent.get('c:IsError');
            if (isError == true) Integer i = 1 / 0;
            return new List<Map<String,Object>>{inputEvent.clone()}; //one message
        }
    }
    
    public class ChunkErrorServiceDefinition extends ApexClassModel.Definition {
        String Description = 'Does stuff in memory without side effects.';
        Integer Chunks = 2;
    }
    
    static testmethod void testKamikazeChunkingDoesntTakeOutHisMates() {
        //arrange cache
        ApexClassSetModel.saveCache(new Map<String,ApexClassModel.Definition>{
            ChunkErrorService.class.getName() => new ApexClassModel.Definition(ChunkErrorService.class),
            ChunkErrorService.class.getName() => new ApexClassModel.Definition(TerminateService.class)
        });
        
        //arrange services, sequence and steps
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        Step__c errorStep = SequenceModel.fromName(sequence.Name).appendStep(ChunkErrorService.class.getName());
        Step__c terminateStep = SequenceModel.fromName(sequence.Name).appendStep(TerminateService.class.getName());
        
        //arrange broker implementation and params
        Map<String,Object> failureEvent = new Map<String,Object>{'c:IsError' => true, 'ToSequence' => 'Test'};
        Map<String,Object> successEvent = new Map<String,Object>{'c:IsError' => false, 'ToSequence' => 'Test'};
        List<Map<String,Object>> events = new List<Map<String,Object>>{failureEvent, successEvent};
        
        //arrange messages and broker
        Test.startTest();
        Enqueue.invoke(events);
        Test.stopTest();
        
        List<Message__c> messages = MessageSetModel.locateMarkableWork().getRecords();
        
        //act
        List<Message__c> outputMessages = new MessageSetModel(messages).execute(null);
        
        //assert #798 should only have one message
        Integer expectedCount = 1;
        Integer actualCount = outputMessages.size();
        System.assertEquals(expectedCount, actualCount);
        
    }
    
    /**
     * Sibling ID population...
     */
    public class FakeGate extends ApexClassModel.Service {
        void callout(Map<String,Object> inputEvent) {}
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            DidRun = true;
            SiblingIds = (Set<Id>)Json.deserialize(Json.serialize(inputEvent.get('SiblingIds')), Set<Id>.class);
            return new List<Map<String,Object>>();
        }
    }
    
    public class FakeGateDefinition extends ApexClassModel.Definition {
        String Description = 'fake gate';
        Integer Chunks = 999;
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
        new MessageSetModel(inputMessages).mark('0000');
        new MessageSetModel(inputMessages).execute(null);
        if (!DidRun) System.assert(false, 'Service probably did not run.');
        System.assertEquals(null, inputMessages[0].Exception__c, 'Wrong exception.');
        
        //assert
        System.assert(SiblingIds.contains(inputMessages[0].Id), 'Message1 id missing.');
        System.assert(SiblingIds.contains(inputMessages[1].Id), 'Message2 id missing.');
    }
    
    
    
    
    
    
    
    
    
    
    
    
    //MASSIVE TODO #1103
    static testmethod void testChunkedMarkContextsCount() {
        //arrange services and sequence and steps
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        Step__c wiretapStep = SequenceModel.fromName(sequence.Name).appendStep(WiretapService.class.getName());
        Step__c terminateStep = SequenceModel.fromName(sequence.Name).appendStep(TerminateService.class.getName());
        
        //arrange messages
        Map<String,Object> inputEvent = new Map<String,Object>{'ToSequence' => 'Test'};
        List<Map<String,Object>> inputEvents = new List<Map<String,Object>>{
            //NINE wiretaps
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
        Enqueue.invoke(inputEvents);
        Test.stopTest();
        
        List<Message__c> messages = [SELECT Id, Event__c FROM Message__c];
        Broker.BatchImpl impl = new Broker.BatchImpl();
        
        //assert
        System.assertEquals(9, [SELECT COUNT() FROM Message__c], 'Wrong initial count.');
        
        //arrange context
        BatchableContext context = new BatchableContext();
        Id jobId = context.getJobId();
        
        impl.start(context);
        
        //MARK some wiretaps
        impl.execute(context, new List<Slot__c>{new Slot__c(Name = '0001')});
        
        //assert
        System.assertEquals(5, impl.InputMessages.size(), 'Wrong count of input wiretaps.');
        System.assertEquals(9, [SELECT COUNT() FROM Message__c], 'Wrong total message count.');
        System.assertEquals(5, [SELECT COUNT() FROM Message__c WHERE Status__c = 'Started'], 'Wrong marked message count.');
        
        //EXECUTE some wiretaps
        impl.execute(context, new List<Slot__c>{new Slot__c(Name = '0002')});
        
        //assert
        System.assertEquals(5, impl.OutputMessages.size(), 'Wrong output property count.');
        
        //PERSIST / MARK
        impl.execute(context, new List<Slot__c>{new Slot__c(Name = '0003')});
        
        //assert
        System.assertEquals(4, impl.InputMessages.size(), 'Wrong count of input wiretaps.');
        System.assertEquals(14, [SELECT COUNT() FROM Message__c ALL ROWS], 'Wrong total message count.'); //#1114
        System.assertEquals(4, [SELECT COUNT() FROM Message__c WHERE Status__c = 'Started'], 'Wrong marked message count.');
        
        //EXECUTE some wiretaps
        impl.execute(context, new List<Slot__c>{new Slot__c(Name = '0004')});
        
        //assert
        System.assertEquals(4, impl.OutputMessages.size(), 'Wrong output property count.');
        
        //PERSIST / MARK
        impl.execute(context, new List<Slot__c>{new Slot__c(Name = '0005')});
        
        //assert
        System.assertEquals(9, impl.InputMessages.size(), 'Wrong count of input terminates.');
        System.assertEquals(18, [SELECT COUNT() FROM Message__c ALL ROWS], 'Wrong total message count.'); //#1114
        System.assertEquals(9, [SELECT COUNT() FROM Message__c WHERE Status__c = 'Started'], 'Wrong marked message count.');
        
        //EXECUTE all terminates
        impl.execute(context, new List<Slot__c>{new Slot__c(Name = '0006')});
        
        //assert
        System.assertEquals(0, impl.OutputMessages.size(), 'Wrong output property count.');
        
        //PERSIST / ABORT
        impl.execute(context, new List<Slot__c>{new Slot__c(Name = '0007')});
        
        //assert
        System.assertEquals(0, impl.InputMessages.size(), 'Wrong count of input messages.');
        System.assertEquals(18, [SELECT COUNT() FROM Message__c ALL ROWS], 'Wrong total message count.'); //#1114
        System.assertEquals(0, [SELECT COUNT() FROM Message__c WHERE Status__c = 'Started'], 'Wrong marked message count.');
        
        System.assert([SELECT Id FROM CronTrigger WHERE Id = :jobId].isEmpty(), 'Job not aborted.');
    }

    static testmethod void testMarkAndExecuteAndDoneConditionAbortsJobAtEnd() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        //arrange steps
        Step__c step = SequenceModel.fromName(sequence.Name).appendStep(TerminateService.class.getName());
        
        //arrange input
        Map<String,Object> inputEvent = new Map<String,Object> {
            'ToSequence' => 'Test'
        };
        
        //arrange message
        Test.startTest();
        Enqueue.invoke(inputEvent);
        Test.stopTest();
        
        //arrange context
        BatchableContext context = new BatchableContext();
        Id jobId = context.getJobId();
        
        //act (enqueue)
        Broker.BatchImpl impl = new Broker.BatchImpl();
        
        //assert
        System.assertEquals(1, [SELECT COUNT() FROM Message__c WHERE Status__c = 'Buffered'], 'Wrong count.');
        
        impl.start(context);
        
        //MARK
        impl.execute(context, new List<SObject>{new Slot__c(Name = '0001')});
        
        //assert
        System.assertEquals(1, impl.InputMessages.size(), 'Wrong input messages.');
        System.assertEquals(1, [SELECT COUNT() FROM Message__c WHERE Status__c = 'Started'], 'Wrong count.');
        
        //EXECUTE
        impl.execute(context, new List<Sobject>{new Slot__c(Name = '0002')});
        
        //assert
        System.assertEquals(0, impl.OutputMessages.size(), 'Wrong output messages.');
        
        //PERSIST AND ABORT
        impl.execute(context, new List<Sobject>{new Slot__c(Name = '0003')});
        
        //assert
        System.assertEquals(1, [SELECT COUNT() FROM Message__c WHERE Status__c = 'Completed' ALL ROWS], 'Wrong count.'); //#1114
        System.assert([SELECT Id FROM CronTrigger WHERE Id = :jobId].isEmpty(), 'Job not aborted.');
    }

    static testmethod void testMarkLimitedToTotalPotentialMarksWhenBufferedMessagesGtTotalPotentialMarks() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        //arrange steps
        Step__c step = SequenceModel.fromName(sequence.Name).appendStep(TerminateService.class.getName());
        
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
        Enqueue.invoke(inputEvent1);
        Enqueue.invoke(inputEvent2);
        Enqueue.invoke(inputEvent3);
        Test.stopTest();
        
        //arrange
        Integer totalPotentialMarks = 3; // Less than Buffered Messages Count
        
        //arrange context
        BatchableContext context = new BatchableContext();
        
        //arrange resolution
        Broker.BatchImpl impl = new Broker.BatchImpl();
        Integer actualBufferedCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Buffered'];
        
        impl.start(context);
        
        //act MARK
        impl.execute(context, new List<SObject>{new Slot__c(Name = '0001')});
        
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
        Step__c step = SequenceModel.fromName(sequence.Name).appendStep(TerminateService.class.getName());
        
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
        Enqueue.invoke(inputEvent1);
        Enqueue.invoke(inputEvent2);
        Enqueue.invoke(inputEvent3);
        Test.stopTest();
        
        //arrange context
        BatchableContext context = new BatchableContext();
        
        //arrange
        Integer totalPotentialMarks = 4;  // Greater than Buffered Messages Count

        //arrange resolution
        Broker.BatchImpl impl = new Broker.BatchImpl();
        Integer actualBufferedCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Buffered'];
        impl.start(context);
        
        //act MARK
        impl.execute(context, new List<SObject>{new Slot__c(Name = '0001')});
        
        //assemble
        Integer actualCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Started'];
        
        //assert
        System.assert(actualBufferedCount > 0, 'Buffered Messages should be greater than zero');
        Integer expectedCount = (totalPotentialMarks > actualBufferedCount) ? actualBufferedCount : totalPotentialMarks;
        System.assertEquals(expectedCount, actualCount, 'Message should be started.');
    }
    
    static testmethod void testPanicConditionAbortsJob() {
        //arrange
        Broker.BatchImpl impl = new Broker.BatchImpl();
        
        //arrange context
        BatchableContext context = new BatchableContext();
        Id jobId = context.getJobId();
        
        try {
            //act, null list should cause panic again
            impl.execute(context, null);
            System.assert(false, 'Line above should throw exception.');
        } catch (Exception e) {
            //assert that panic was thrown
            String expectedMessage = 'PANIC';
            String actualMessage = e.getMessage();
            System.assert(actualMessage.contains(expectedMessage), 'Wrong message');
        }
        
        //act (should abort from previous panic)
        impl.execute(context, null);
        
        //assert that job was aborted
        System.assert([SELECT Id FROM CronTrigger WHERE Id = :jobId].isEmpty(), 'Job not aborted.');
        
    }
    
    public class FinishDoesPersist {
        void callout(Map<String,Object> event) {}
        List<Map<String,Object>> execute(Map<String,Object> event) {return new List<Map<String,Object>>{new Map<String,Object>()};}
    }
    
    public class FinishDoesPersistDefinition extends ApexClassModel.Definition {
        Integer Chunks = 1;
    }
    
    //for #991 very last Execute should get Persisted
    static testmethod void testAllContextsDoneOk() {
        //arrange services and sequence and steps
        insert new Sequence__c(Name = 'Test');
        SequenceModel.fromName('Test').appendStep(FinishDoesPersist.class.getName());
        SequenceModel.fromName('Test').appendStep(FinishDoesPersist.class.getName());
        SequenceModel.fromName('Test').appendStep(FinishDoesPersist.class.getName());
        SequenceModel.fromName('Test').appendStep(FinishDoesPersist.class.getName());
        SequenceModel.fromName('Test').appendStep(TerminateService.class.getName());
        
        //arrange broker
        Broker.BatchImpl impl = new Broker.BatchImpl();
        
        //arrange inputs (5 messages, 1 mark and 1 execute for each, should make 10 contexts)
        List<Map<String,Object>> events = new List<Map<String,Object>>();
        for (Integer i = 0; i < 5; i++) events.add(new Map<String,Object>{'ToSequence' => 'Test'});
        
        //arrange messages
        Test.startTest();
        Enqueue.invoke(events);
        Test.stopTest();
        
        //arrange context
        Database.BatchableContext context = new BatchableContext();
        
        //act
        
        impl.Contexts = 9;
        impl.start(context);
        impl.execute(context, new List<Slot__c>{new Slot__c(Name = '0001')}); //M1
        impl.execute(context, new List<Slot__c>{new Slot__c(Name = '0002')}); //E1
        impl.execute(context, new List<Slot__c>{new Slot__c(Name = '0003')}); //P1 M2
        impl.execute(context, new List<Slot__c>{new Slot__c(Name = '0004')}); //E2
        impl.execute(context, new List<Slot__c>{new Slot__c(Name = '0005')}); //P2 M3
        impl.execute(context, new List<Slot__c>{new Slot__c(Name = '0006')}); //E3
        impl.execute(context, new List<Slot__c>{new Slot__c(Name = '0007')}); //P3 M4
        impl.execute(context, new List<Slot__c>{new Slot__c(Name = '0008')}); //E4
        impl.execute(context, new List<Slot__c>{new Slot__c(Name = '0009')}); //P4 M5
        impl.execute(context, new List<Slot__c>{new Slot__c(Name = '0010')}); //E5
        impl.finish(context);                                                 //P5
        
        //assert
        Integer expectedCount = 5;
        Integer actualCount = [SELECT COUNT() FROM Message__c ALL ROWS]; //#1114
        System.assertEquals(expectedCount, actualCount, 'Wrong count.');
    }
}