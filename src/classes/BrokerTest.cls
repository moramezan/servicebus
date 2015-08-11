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
    public with sharing class SynchronousBroker extends Broker {
        
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
            this.persist(inputAndOutputMessages); //#782
            
            super.run();
        }
        
    }

    static testmethod void testChunkingMarkFindsMultipleWork() {
        //arrange processes and sequence and steps
        Sequence__c sequence = new Sequence__c(Name = 'test');
        insert sequence;
        
        Step__c wiretapStep = SequenceModel.fromName(sequence.Name).appendStep(Wiretap.class);
        Step__c terminateStep = SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
        
        //arrange messages
        Map<String,Object> inputEvent = new Map<String,Object>{'__SequenceName' => 'test', '__Position' => 1};
        
        List<Map<String,Object>> outputEvents = new List<Map<String,Object>>{
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
        
        List<Message__c> messages = new Job(outputEvents).persist();
        
        //act
        List<Message__c> records = Broker.impl().locateMarkableWork();
        
        //assert
        Integer expectedLimits = 5;
        Integer actualLimits = new Wiretap.ESB().Limits;
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
        new Job(sequence.Name, '000000000000000AAA').persist();
        
        //assert
        Integer expectedBuffered = 1;
        Integer actualBuffered = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Buffered'];
        System.assertEquals(expectedBuffered, actualBuffered, 'Wrong count.');
        
        //act
        Broker.MaxHops = 2;
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
        String expectedException = 'Too many hops - to resolve, manually set __Hops on event parameters to 0';
        String actualException = message.Exception__c;
        System.assertEquals(expectedException, actualException, 'Wrong exception.');
    }
    
    static testmethod void callingEnforceMaxHopsReturnsExpectedValueWhenHopsLtThreshold() {
        //arrange
        Broker.MaxHops = 2;
        List<Message__c> messages = new Job(new Map<String,Object>{
            //'__Hops' => 0 //enqueue sets hops
        }).persist();
        
        //act
        new MessageSetModel(messages).incrementHops();
        
        //assemble
        Map<String,Object> inputEvent = (Map<String,Object>)Json.deserializeUntyped(messages[0].Event__c);

        //assert
        Integer expectedHops = 1;
        Integer actualHops = (Integer)inputEvent.get('__Hops');
        System.assertEquals( expectedHops, actualHops);
    }



    static testmethod void callingEnforceMaxHopsReturnsExpectedValueWhenHopsNotDefined() {
       //arrange
        Broker.MaxHops = 10;
        List<Message__c> messages = new Job(new Map<String,Object>{
            //enqueue sets hops
        }).persist();

        //act
        new MessageSetModel(messages).incrementHops();
        
        //assemble
        Map<String,Object> inputEvent = (Map<String,Object>)Json.deserializeUntyped(messages[0].Event__c);

        //assert
        Integer expectedHops = 1;
        Integer actualHops = (Integer)inputEvent.get('__Hops');
        System.assertEquals( expectedHops, actualHops);
    }
 
  
    static testmethod void callingEnforceMaxHopsThrowsExceptionWhenHopsGtOrEqToThreshold() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        Step__c terminateStep = SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
        
        //arrange message
        Broker.MaxHops = 1;
        List<Message__c> messages = new Job(new Map<String,Object>{
            'esb__SequenceName' => 'Test'
            //'esb__Hops' => 0 //enqueue sets hops
        }).persist();
        
        //assemble
        //http://salesforce.stackexchange.com/q/61213/320
        messages = Broker.impl().locateMarkableWork();
        
        Boolean actualFlag = false;
        
        //act
        Broker.impl().execute(messages, new List<Message__c>());
        
        //assemble
        actualFlag = messages[0].Exception__c != null;

        //assert
        Boolean expectedFlag = true;
        System.assertEquals( expectedFlag, actualFlag);
    }
    
    
    static testmethod void canCorrectlyIncrementAndPersistMessages() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        //arrange steps
        SequenceModel model = SequenceModel.fromId(sequence.Id);
        Step__c stepA1 = model.appendStep(Subscribe.class);
        Step__c stepA2 = model.appendStep(Publish.class);
        Step__c stepA3 = model.appendStep(Terminate.class);
        Integer positionA1 = stepA1.Position__c.intValue();
        Integer positionA2 = stepA2.Position__c.intValue();
        Integer positionA3 = stepA3.Position__c.intValue();
        
        List<Map<String,Object>> outputEvents = new List<Map<String,Object>>{
            new Map<String,Object>{'__SequenceName' => 'sequenceName1', '__Position' => positionA1},
            new Map<String,Object>{'__SequenceName' => 'sequenceName2', '__Position' => positionA2}
        };
        
        
        //act
        List<Message__c> messages = new Job(outputEvents).persist();
        new MessageSetModel(messages).incrementPositions();
        
        //assemble
        Map<String,Object> inputEvent1 = (Map<String,Object>)System.Json.deserializeUntyped(messages[0].Event__c);
        Map<String,Object> inputEvent2 = (Map<String,Object>)System.Json.deserializeUntyped(messages[1].Event__c);
        
        // assert
        Integer expectedCount = 2;
        Integer actualCount = messages.size();
        System.assertEquals(expectedCount, actualCount);

        String expectedSequenceName1 = 'sequenceName1';
        String actualSequenceName1 = (String)inputEvent1.get('__SequenceName');
        System.assertEquals(expectedSequenceName1, actualSequenceName1, 'Wrong sequence name');
        
        Integer expectedPosition1 = positionA1 + 1;
        Integer actualPosition1 = (Integer)inputEvent1.get('__Position');
        System.assertEquals(expectedPosition1, actualPosition1, 'Wrong position 1.');

        String expectedSequenceName2 = 'sequenceName2';
        String actualSequenceName2 = (String)inputEvent2.get('__SequenceName');
        System.assertEquals(expectedSequenceName2, actualSequenceName2, 'Wrong sequence name');
        
        Integer expectedPosition2 = positionA2 + 1;
        Integer actualPosition2 = (Integer)inputEvent2.get('__Position');
        System.assertEquals(expectedPosition2, actualPosition2, 'Wrong position 2.');
    }
    
    static testmethod void testLocatorMarksCorrectNumberOfMessages() {
        //arrange
        Sequence__c sequence = new Sequence__c(Name = 'test');
        insert sequence;
        
        Step__c terminateStep = SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
        
        new Job(new List<Map<String,Object>>{
            new Map<String,Object>{'__SequenceName' => 'test', '__Position' => 1},
            new Map<String,Object>{'__SequenceName' => 'test', '__Position' => 1},
            new Map<String,Object>{'__SequenceName' => 'test', '__Position' => 1}
        }).persist();
        
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
        Sequence__c sequence = new Sequence__c(Name = 'test');
        insert sequence;
        
        Step__c terminateStep = SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
        
        //arrange fucked messages
        insert new List<Message__c>{
            new Message__c(Status__c = 'Started', Event__c = '{"__SequenceName":"test","__Position":1}'),
            new Message__c(Status__c = 'Started', Event__c = '{"__SequenceName":"test","__Position":1}')
        };
        
        //arrange Buffered messages
        insert new List<Message__c>{
            new Message__c(Status__c = 'Buffered', Event__c = '{"__SequenceName":"test","__Position":1}'),
            new Message__c(Status__c = 'Buffered', Event__c = '{"__SequenceName":"test","__Position":1}')
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
    
    static testmethod void canCorrectlyIncrementMessages() {
        // arrange
        String sequenceNameA = 'sequenceA';
        String sequenceNameB = 'sequenceB';
        String sequenceNameC = 'sequenceC';
        Sequence__c sequenceA = new Sequence__c(Name = sequenceNameA);
        Sequence__c sequenceB = new Sequence__c(Name = sequenceNameB);
        Sequence__c sequenceC = new Sequence__c(Name = sequenceNAmeC);
        insert sequenceA;
        insert sequenceB;
        insert sequenceC;

        Integer positionA1 = 1;
        Integer positionA2 = 2;
        Integer positionA3 = 3;
        Integer positionB1 = 1;
        Integer positionB2 = 2;
        Integer positionC1 = 1;
        Integer positionC2 = 2;
        Step__c stepA1 = SequenceModel.fromName(sequenceA.Name).appendStep(Subscribe.class);
        Step__c stepA2 = SequenceModel.fromName(sequenceA.Name).appendStep(Publish.class);
        Step__c stepA3 = SequenceModel.fromName(sequenceA.Name).appendStep(Terminate.class);
        Step__c stepB1 = SequenceModel.fromName(sequenceB.Name).appendStep(Wiretap.class);
        Step__c stepB2 = SequenceModel.fromName(sequenceB.Name).appendStep(Terminate.class);
        Step__c stepC1 = SequenceModel.fromName(sequenceC.Name).appendStep(Publish.class);
        Step__c stepC2 = SequenceModel.fromName(sequenceC.Name).appendStep(Terminate.class);
        
        List<Map<String,Object>> outputEvents = new List<Map<String,Object>>{
            new Map<String,Object>{'esb__Id' => 0, '__SequenceName' => sequenceA.Name, '__Position' => positionA1}, // Same Sequence / Position
            new Map<String,Object>{'esb__Id' => 1, '__SequenceName' => sequenceA.Name, '__Position' => positionA1}, // Same Sequence / Position
            new Map<String,Object>{'esb__Id' => 2, '__SequenceName' => sequenceA.Name, '__Position' => positionA2},
            new Map<String,Object>{'esb__Id' => 3, '__SequenceName' => sequenceB.Name, '__Position' => positionB1},
            new Map<String,Object>{'esb__Id' => 4, '__SequenceName' => sequenceC.Name, '__Position' => positionC1}
        };
        
        // act
        List<Message__c> messages = new Job(outputEvents).persist();
        new MessageSetModel(messages).incrementPositions();
        
        // assemble
        String actualSequenceName0 = '' ;
        String actualSequenceName1 = '' ;
        String actualSequenceName2 = '' ;
        String actualSequenceName3 = '' ;
        String actualSequenceName4 = '' ;
        Integer actualPosition0 = -1 ;
        Integer actualPosition1 = -1 ;
        Integer actualPosition2 = -1 ;
        Integer actualPosition3 = -1 ;
        Integer actualPosition4 = -1 ;
        for (Message__c message : messages) {
            Map<String,Object> inputEvent = (Map<String,Object>)System.Json.deserializeUntyped(message.Event__c);
            Integer theId = (Integer) inputEvent.get('esb__Id');
            String theSequenceName = (String)inputEvent.get('__SequenceName');
            Integer thePosition = (Integer)inputEvent.get('__Position');
            if (theId == 0) {
                actualSequenceName0 = theSequenceName;
                actualPosition0 = thePosition;
            }
          
            if (theId == 1) {
                actualSequenceName1 = theSequenceName;
                actualPosition1 = thePosition;
            }
            if (theId == 2) {
                actualSequenceName2 = theSequenceName;
                actualPosition2 = thePosition;
            
            }
            if (theId == 3) {
                actualSequenceName3 = theSequenceName;
                actualPosition3 = thePosition;
            }
            if (theId == 4) {
                actualSequenceName4 = theSequenceName;
                actualPosition4 = thePosition;
            }
        }
        
        // assert
        Integer expectedCount = 5;
        Integer actualCount = messages.size();
        System.assertEquals(expectedCount, actualCount);
        
        String expectedSequenceName0 = sequenceNameA;
        String expectedSequenceName1 = sequenceNameA;
        String expectedSequenceName2 = sequenceNameA;
        String expectedSequenceName3 = sequenceNameB;
        String expectedSequenceName4 = sequenceNameC;
        Integer expectedPosition0 = positionA1 + 1;
        Integer expectedPosition1 = positionA1 + 1;
        Integer expectedPosition2 = positionA2 + 1;
        Integer expectedPosition3 = positionB1 + 1;
        Integer expectedPosition4 = positionC1 + 1;
        System.assertEquals(expectedPosition0, actualPosition0);
        System.assertEquals(expectedPosition1, actualPosition1);
        System.assertEquals(expectedPosition2, actualPosition2);
        System.assertEquals(expectedPosition3, actualPosition3);
        System.assertEquals(expectedPosition4, actualPosition4);
        System.assertEquals(expectedSequenceName0, actualSequenceName0);
        System.assertEquals(expectedSequenceName1, actualSequenceName1);
        System.assertEquals(expectedSequenceName2, actualSequenceName2);
        System.assertEquals(expectedSequenceName3, actualSequenceName3);
        System.assertEquals(expectedSequenceName4, actualSequenceName4);
    }
    
    static testmethod void callingEnqueueSuccessfullyCallsrunImpl() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange steps
        SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
        
        //arrange broker implementation custom setting
        String theSequenceName = 'TestSequence';
        Id theId = '000000000000000AAA';
        
        //assert
        Boolean expectedBeforeFlag = false;
        Boolean actualBeforeFlag = BrokerTest.DidSynchronousBrokerRun;
        System.assertEquals(expectedBeforeFlag, actualBeforeFlag);
        
        //IT'S a @FUTURE CALL ... dont want that to happen every time
        
        //act
        new Job(theSequenceName, theId).execute(null);
        
        //assert
        Boolean expectedAfterFlag = true;
        Boolean actualAfterFlag = DidSynchronousBrokerRun;
        System.assertEquals(expectedAfterFlag, actualAfterFlag);
    }
    
    static testmethod void callingEnqueueSuccessfullyCallEnqueueImpAndCreatesDocument() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange steps
        SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
        
        //assert
        Boolean expectedBeforeFlag = false;
        Boolean actualBeforeFlag = BrokerTest.DidSynchronousBrokerRun;
        System.assertEquals(expectedBeforeFlag, actualBeforeFlag);
        
        Integer expectedSizeBefore = 0;
        Integer actualSizeBefore = [SELECT COUNT() FROM Document];
        System.assertEquals(expectedSizeBefore , actualSizeBefore);
        
        //act (this calls blob enqueue signature that does inserts a document)
        new Job('TestSequence', Blob.valueOf('balls')).execute(null);
        
        //assert
        Integer expectedSizeAfter = 1;
        Integer actualSizeAfter = [SELECT COUNT() FROM Document];
        System.assertEquals(expectedSizeAfter, actualSizeAfter);
        
        Boolean expectedAfterFlag = true;
        Boolean actualAfterFlag = BrokerTest.DidSynchronousBrokerRun;
        System.assertEquals(expectedAfterFlag, actualAfterFlag);
    }
    
    static testmethod void callingRestartSuccessfullyCallsrunImpl() {
        //arrange
        List<Message__c> messages = new Job('test', UserInfo.getUserId()).persist();
        
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
        //arrange message
        Map<String,Object> inputEvent = new Map<String,Object>{'not__Position' => 1};
        List<Message__c> messages = new Job(inputEvent).persist();
        
        //arrange broker
        Broker impl = Broker.impl();
        
        String actualMessage;
        
        //act
        impl.execute(messages, new List<Message__c>());
        
        //assemble
        actualMessage = messages[0].Exception__c;
        
        //assert
        String expectedMessage = 'This message has no route: ' + messages[0].Id;
        System.assertEquals(expectedMessage, actualMessage, 'Wrong exception message.');
    }
    
    
    
    // TODO - Test Fails
    //        Assume it will be fixed when deailing with Issue "migrate chunking logic into abstract Broker #636"
    // Method Name      testNoStepThrowsQueryException
    // Error Message    System.AssertException: Assertion Failed: Message cannot have a null process.
    // Stack Trace      Class.BrokerTest.testNoStepThrowsQueryException: line 705, column 1
    static testmethod void testNoStepThrowsQueryException() {
        //arrange message (note there is no Step__c in database!)
        Map<String,Object> inputEvent = new Map<String,Object>{'__SequenceName' => '', '__Position' => 0};
        List<Message__c> messages = new Job(inputEvent).persist();
        
        //arrange specific broker implementation
        Broker impl = Broker.impl();
        
        String actualMessage;
        
        //act
        impl.execute(messages, new List<Message__c>());
        
        //assemble
        actualMessage = messages[0].Exception__c;
        
        //assert
        String expectedMessage = 'This message has no route: ' + messages[0].Id;
        System.assertEquals(expectedMessage, actualMessage, 'Wrong message.');
    }
    
    static testmethod void testProcessWithoutClassThrowsExpectedException() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange steps
        Step__c step = SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
        step.ApexClassName__c = 'lalala';
        update step;
        
        //act
        new Job(sequence.Name, '000000000000000AAA').execute(null);
        
        //assemble
        Message__c message = [SELECT Id, Cause__c, Exception__c FROM Message__c];
        Map<String,Object> actualEx = (Map<String,Object>)Json.deserializeUntyped(message.Cause__c);
        
        //assert
        String actualMessage = message.Exception__c;
        String expectedMessage = 'Reflector for classname was null: lalala';
        System.assertEquals(expectedMessage, (String)actualEx.get('Message'), 'Wrong message detail.');
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
        // arrange
        Boolean isPaused =  true;

        String sequenceNameA = 'sequenceA';
        Sequence__c sequenceA = new Sequence__c(Name = sequenceNameA);
        insert sequenceA;


        Integer positionA1 = 1;
        Integer positionA6 = 2;

        Step__c stepA1 = SequenceModel.fromName(sequenceA.Name).appendStep(Wiretap.class);
        Step__c stepA6 = SequenceModel.fromName(sequenceA.Name).appendStep(Terminate.class);

        //arrange specific broker implementation
        insert new BrokerSetting__c(IsPaused__c = isPaused);

        //act
        new Job(sequenceNameA, '000000000000000AAA').execute(null);


        //assemble
        List<Message__c> messages = [
            SELECT Id, Name, Event__c, Status__c
            FROM Message__c
            WHERE Status__c != 'Completed'
        ];
        
        Integer expectedSize = 1;
        Integer actualSize = messages.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
        
        //assert
        String expectedStatus = 'Paused';
        String actualStatus = messages[0].Status__c;
        System.assertEquals(expectedStatus, actualStatus, 'Wrong status.');
    }

    static testmethod void callingEnqueueWhenBrokerIsNotPausedProcessesMessages() {
        // arrange
        Boolean isPaused =  false;

        String sequenceNameA = 'sequenceA';
        Sequence__c sequenceA = new Sequence__c(Name = sequenceNameA);
        insert sequenceA;


        Integer positionA1 = 1;
        Integer positionA2 = 2;
        Integer positionA3 = 3;
        Integer positionA4 = 4;
        Integer positionA5 = 5;
        Integer positionA6 = 6;

        Step__c stepA1 = SequenceModel.fromName(sequenceA.Name).appendStep(Wiretap.class);
        Step__c stepA2 = SequenceModel.fromName(sequenceA.Name).appendStep(Wiretap.class);
        Step__c stepA3 = SequenceModel.fromName(sequenceA.Name).appendStep(Wiretap.class);
        Step__c stepA4 = SequenceModel.fromName(sequenceA.Name).appendStep(Wiretap.class);
        Step__c stepA5 = SequenceModel.fromName(sequenceA.Name).appendStep(Wiretap.class);
        Step__c stepA6 = SequenceModel.fromName(sequenceA.Name).appendStep(Terminate.class);

        //act
        new Job(sequenceNameA, '000000000000000AAA').execute(null);

        Integer expectedCount = 6;
        Integer actualCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Completed'];
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
        String sequenceNameA = 'sequenceA';
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
        new Job(sequenceNameA, '000000000000000AAA').execute(null);

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
        
        String expectedException = 'Nonexistent route, eg bad sequence name, position, missing terminate: sequenceA#4';
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
        DateTime eventStamp = DateTime.newInstance(2014,12,15,13,11,07);
        Map<String,Object> inputEvent = new Map<String,Object>{
            'esb__Id' => UserInfo.getUserId(),
            '__SequenceName' => 'Test',
            '__Position' => 1,
            'esb__EntryPointDatetime' => eventStamp
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
        
        DateTime expectedEventStamp = eventStamp;
        DateTime actualEventStamp = (DateTime)Json.deserialize('"' + ((String)actualEvent.get('esb__EntryPointDatetime')) + '"', DateTime.class);
        System.assertEquals(expectedEventStamp, actualEventStamp);
    }

    static testMethod void callingExecuteWithoutMandatoryEventParametersInEventParametersCollectionThrowsException() {
        // arrange process, sequence, step
        String sequenceName = 'Test';
        Sequence__c sequence = new Sequence__c(Name = sequenceName);
        insert sequence;
        
        Step__c step = SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
  
        //arrange messages
        List<Message__c> messagesA = new Job(new Map<String,Object>{'__SequenceName' => 'test'}).persist();
        List<Message__c> messagesB = new Job(new Map<String,Object>{'esb__Id' => null}).persist();
        
        // assemble
        Boolean actualFlagA = false;
        
        // act
        Broker.impl().execute(messagesA, new List<Message__c>());
        
        actualFlagA = messagesA[0].Exception__c != null;
        
        // assemble
        Boolean actualFlagB = false;
        
        // act
        Broker.impl().execute(messagesB, new List<Message__c>());
        
        actualFlagB = messagesB[0].Exception__c != null;
        
        // assert
        Boolean expectedFlagA = true;
        System.assertEquals(expectedFlagA,actualFlagA);
        Boolean expectedFlagB = true;
        System.assertEquals(expectedFlagB,actualFlagB);
    }
    
    
    static testMethod void callingEnqueueAlwaysSetsInitiatingEventParameters() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        //arrange steps
        SequenceModel model = SequenceModel.fromId(sequence.Id);
        model.appendStep(Terminate.class);
        
        //act
        new Job(sequence.Name, '000000000000000AAA').execute(null);
        
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
        String actualEntryPointUuid = (String)inputEvent.get('__EntryPointUuid');
        System.assertNotEquals(unexpectedEntryPointUuid, actualEntryPointUuid, 'Wrong entry point uuid.');
        
        Integer expectedPosition = 1;
        Integer actualPosition = (Integer)inputEvent.get('__Position');
        System.assertEquals(expectedPosition, actualPosition, 'Wrong position.');
        
        Id expectedEnqueueUserId = UserInfo.getUserId();
        Id actualEnqueueUserId = (Id)inputEvent.get('__EnqueueUserId');
        System.assertEquals(expectedEnqueueUserId, actualEnqueueUserId, 'Wrong enqueue user id.');
    }

    static testMethod void callingInvokeMainWithCorrectToToStringOverrideDoesNOTThrowException() {
        //arrange
        Map<String,Object> inputEvent = new Map<String,Object>();
        
        //act
        Boolean actualFlag = true;
        Type reflector = Terminate.class;
        try {
            System.assert(false, 'TODO'); //TODO Broker.Wrapper wrapper = new Broker.Wrapper(reflector, inputEvent).invokeMain();
        } catch (Exception e) {
            actualFlag = false;
        }
        
        //assert
        Boolean expectedFlag = true;
        System.assertEquals(expectedFlag, actualFlag, 'Unexpected error thrown by wrapper invokeMain()');
    }
    
    static testMethod void callingInvokeMainWhenNoToToStringOverrideThrowsExpectedException() {
        //arrange
        Map<String,Object> inputEvent = new Map<String,Object>();
        Type reflector = PostInstallHandler.class; // Clearly, no toString() override here!
        
        //act
        Boolean actualFlag = false;
        try {
            System.assert(false, 'TODO'); //TODO Broker.Wrapper wrapper = new Broker.Wrapper(reflector, inputEvent).invokeMain();
            System.assert(false, 'Above should throw exception.');
        } catch (Exception e) {
            String expectedMessage = 'Your plugin has not overridden the toString() method. Please refer to the Process Developers Guide for specific guidance.';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage, 'Wrong message.');
        }
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
    
    public class ChunkErrorProcess extends ApexClassModel.BaseProcess {
        override protected List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            Boolean isError = (Boolean)inputEvent.get('c__IsError');
            if (isError == true) throw new ChunkErrorProcessException('Test error');
            return new List<Map<String,Object>>{inputEvent.clone()}; //one message
        }
    }
    
    public class ChunkErrorProcessESB extends ApexClassModel.BaseSummary {
        public String Description = 'Does stuff in memory without side effects.';
        public Integer Limits = 2;
    }
    
    static testmethod void testKamikazeChunkingDoesntTakeOutHisMates() {
        //arrange processes, sequence and steps
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        Step__c errorStep = SequenceModel.fromName(sequence.Name).appendStep(ChunkErrorProcess.class);
        Step__c terminateStep = SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
        
        //arrange broker implementation and params
        Map<String,Object> failureEvent = new Map<String,Object>{'c__IsError' => true, '__SequenceName' => 'Test', '__Position' => 1};
        Map<String,Object> successEvent = new Map<String,Object>{'c__IsError' => false, '__SequenceName' => 'Test', '__Position' => 1};
        List<Map<String,Object>> events = new List<Map<String,Object>>{failureEvent, successEvent};
        
        //arrange messages and broker
        List<Message__c> messages = new Job(events).persist();
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
    
    public class Inserter extends ApexClassModel.BaseProcess {
        override protected List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            Map<String,Object> outputEvent = inputEvent.clone();
            insert new Document(Name = 'Test.txt', FolderId = UserInfo.getUserId());
            return new List<Map<String,Object>>();
        }
    }
    
    public class InserterESB extends ApexClassModel.BaseSummary {
        public String Description = 'Inserts 1 document, runs 75 times';
        public Integer Limits = 75;
    }
    
    static testmethod void testSavepointTaxImposedOnDmlProcess() {
        //arrange broker
        Broker impl = Broker.impl();
        
        //arrange sequence
        insert new Sequence__c(Name = 'Sequence');
        SequenceModel model = SequenceModel.fromName('Sequence');
        
        //arrange steps
        model.appendStep(Inserter.class);
        
        //arrange events
        List<Map<String,Object>> events = new List<Map<String,Object>>();
        for (Integer i = 0; i < 75; i++) {
            Map<String,Object> event = new Map<String,Object>{'esb__SequenceName' => 'Sequence'};
            events.add(event);
        }
        
        //arrange messages
        new Job(events).persist();
        List<Message__c> inputMessages = impl.locateMarkableWork();
        List<Message__c> outputMessages = new List<Message__c>();
        impl.mark(inputMessages);
        
        //act and assemble
        Test.startTest();
        impl.execute(inputMessages, outputMessages);
        Integer dmlStatements = Limits.getDMLStatements();
        Test.stopTest();
        
        //assert
        Integer expectedStatements = 150; //75 savepoints, 75 documents
        Integer actualStatements = dmlStatements;
        System.assertEquals(expectedStatements, actualStatements, 'Wrong DML count.');
    }
    
    public class Memory extends ApexClassModel.BaseProcess {
        override protected List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            inputEvent.put('c__OrganizationId', UserInfo.getOrganizationId());
            return new List<Map<String,Object>>();
        }
    }
    
    public class MemoryESB extends ApexClassModel.BaseSummary {
        public String Description = 'Does stuff in memory without side effects.';
        public Integer Limits = 1000;
    }
    
    static testmethod void testSavepointTaxRelievedOnMemoryProcess() {
        //arrange broker
        Broker impl = Broker.impl();
        
        //arrange sequence
        insert new Sequence__c(Name = 'Sequence');
        SequenceModel model = SequenceModel.fromName('Sequence');
        
        //arrange steps
        model.appendStep(Memory.class);
        
        //arrange events
        List<Map<String,Object>> events = new List<Map<String,Object>>();
        for (Integer i = 0; i < 1000; i++) {
            Map<String,Object> event = new Map<String,Object>{'esb__SequenceName' => 'Sequence'};
            events.add(event);
        }
        
        //arrange messages
        new Job(events).persist();
        List<Message__c> inputMessages = impl.locateMarkableWork();
        List<Message__c> outputMessages = new List<Message__c>();
        impl.mark(inputMessages);
        
        //act and assemble
        Test.startTest();
        impl.execute(inputMessages, outputMessages);
        Integer dmlStatements = Limits.getDMLStatements();
        Test.stopTest();
        
        //assert
        Integer expectedStatements = 1; //exactly 1 savepoint
        Integer actualStatements = dmlStatements;
        System.assertEquals(expectedStatements, actualStatements, 'Wrong DML count.');
    }
    
    public class InserterErrorException extends Exception {}
    
    public class InserterError extends ApexClassModel.BaseProcess {
        override protected List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            insert new Document(Name = 'Test.txt', FolderId = UserInfo.getUserId());
            throw new InserterErrorException('Something catchable.');
        }
    }
    
    public class InserterErrorESB extends ApexClassModel.BaseSummary {
        public String Description = 'Inserts 1 document, throws an exception needing rollback.';
        public Integer Limits = 50;
    }
    
    static testmethod void testRollbackTaxImposedOnDmlProcess() {
        //arrange broker
        Broker impl = Broker.impl();
        
        //arrange sequence
        insert new Sequence__c(Name = 'Sequence');
        SequenceModel model = SequenceModel.fromName('Sequence');
        
        //arrange steps
        model.appendStep(InserterError.class);
        
        //arrange events
        List<Map<String,Object>> events = new List<Map<String,Object>>();
        for (Integer i = 0; i < 50; i++) {
            Map<String,Object> event = new Map<String,Object>{'esb__SequenceName' => 'Sequence'};
            events.add(event);
        }
        
        //arrange messages
        new Job(events).persist();
        List<Message__c> inputMessages = impl.locateMarkableWork();
        List<Message__c> outputMessages = new List<Message__c>();
        impl.mark(inputMessages);
        
        //act and assemble
        Test.startTest();
        impl.execute(inputMessages, outputMessages);
        Integer dmlStatements = Limits.getDmlStatements();
        Test.stopTest();
        
        //assert
        Integer expectedStatements = 150; //50 savepoints, 50 documents, 50 rollbacks
        Integer actualStatements = dmlStatements;
        System.assertEquals(expectedStatements, actualStatements, 'Wrong DML count.');
    }
    
    public class MemoryErrorException extends Exception {}
    
    public class MemoryError extends ApexClassModel.BaseProcess {
        override protected List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            inputEvent.put('c__OrganizationId', UserInfo.getOrganizationId());
            throw new MemoryErrorException('Something catchable.');
        }
    }
    
    public class MemoryErrorESB extends ApexClassModel.BaseSummary {
        public String Description = 'Does stuff in memory, throws an exception not needing rollback.';
        public Integer Limits = 1000;
    }
    
    static testmethod void testRollbackTaxRelievedOnMemoryProcess() {
        //arrange broker
        Broker impl = Broker.impl();
        
        //arrange sequence
        insert new Sequence__c(Name = 'Sequence');
        SequenceModel model = SequenceModel.fromName('Sequence');
        
        //arrange steps
        model.appendStep(MemoryError.class);
        
        //arrange events
        List<Map<String,Object>> events = new List<Map<String,Object>>();
        for (Integer i = 0; i < 1000; i++) {
            Map<String,Object> event = new Map<String,Object>{'esb__SequenceName' => 'Sequence'};
            events.add(event);
        }
        
        //arrange messages
        new Job(events).persist();
        List<Message__c> inputMessages = impl.locateMarkableWork();
        List<Message__c> outputMessages = new List<Message__c>();
        impl.mark(inputMessages);
        
        //act and assemble
        Test.startTest();
        impl.execute(inputMessages, outputMessages);
        Integer dmlStatements = Limits.getDmlStatements();
        Test.stopTest();
        
        //assert
        Integer expectedStatements = 1; //exactly 1 savepoint
        Integer actualStatements = dmlStatements;
        System.assertEquals(expectedStatements, actualStatements, 'Wrong DML count.');
    }
    
}