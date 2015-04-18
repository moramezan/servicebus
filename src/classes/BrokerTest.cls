@IsTest public class BrokerTest { //formerly FailureProcess
    
    public String Event;
    
    @TestVisible private class ESB {
        public String Tag = 'Enterprise Service Bus';
        public String Name = 'Failure Process';
        public String Description = 'A toStringable Object that throws an exception for testing purposes.'; //Will not be listed
    }
    
    override public String toString() {
        System.assert(this.Event != null);
        Map<String,Object> inputEvent = (Map<String,Object>)Json.deserializeUntyped(this.Event);
        throw new BrokerException(FailureMessage);
        return Json.serialize(new List<Map<String,Object>>{inputEvent});
    }
    
    public class BrokerException extends Exception {}

    public class DoNothingBroker extends Broker {
        override public void runImpl() {}
        override public Boolean isRunning() {return true;}
    }
    
    @TestVisible static private String FailureMessage = 'Fake Error Thrown in FailureProcess';
    
    static public Boolean flagrunImpl = false;
    public class MockBroker extends Broker {
        override public Boolean isRunning() {
            return false;
        }
        
        override public void runImpl() {
            flagrunImpl = true;
        }
    }

    static testmethod void testChunkingMarkFindsMultipleWork() {
        //arrange broker
        insert new BrokerSetting__c(BrokerClassName__c = SynchronousBroker.class.getName());
        
        //arrange processes and sequence and steps
        Sequence__c sequence = new Sequence__c(Name = 'test');
        insert sequence;
        
        Step__c wiretapStep = StepModel.generateOne(sequence.Name, Wiretap.class.getName());
        Step__c terminateStep = StepModel.generateOne(sequence.Name, Terminate.class.getName());
        
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
        // arrange
        Integer maxHops = 3;
        Broker.MaxHops = maxHops;

        String sequenceNameA = 'sequenceA';
        Sequence__c sequenceA = new Sequence__c(Name = sequenceNameA);
        insert sequenceA;


        Integer positionA1 = 1;
        Integer positionA2 = 2;
        Integer positionA3 = 3;
        Integer positionA4 = 4;
        Integer positionA5 = 5;
        Integer positionA6 = 6;

        Step__c stepA1 = StepModel.generateOne(sequenceA.Name, Wiretap.class.getName());
        Step__c stepA2 = StepModel.generateOne(sequenceA.Name, Wiretap.class.getName());
        Step__c stepA3 = StepModel.generateOne(sequenceA.Name, Wiretap.class.getName());
        Step__c stepA4 = StepModel.generateOne(sequenceA.Name, Wiretap.class.getName());
        Step__c stepA5 = StepModel.generateOne(sequenceA.Name, Wiretap.class.getName());
        Step__c stepA6 = StepModel.generateOne(sequenceA.Name, Terminate.class.getName());

        //arrange specific broker implementation
        insert new BrokerSetting__c(BrokerClassName__c = SynchronousBroker.class.getName());
        
        //act
        new Job(sequenceNameA, '000000000000000AAA').execute(null);
        
        //assemble
        List<Message__c> messages = [
            SELECT Id, Name, Event__c, Status__c, Cause__c
            FROM Message__c
            WHERE Status__c != 'Completed'
        ];
        
        Integer actualHops;
        String actualDetail;
        String actualStatus;
        Integer actualCount = messages.size();
        if (actualCount > 0) {
            Map<String,Object> actualEvent = (Map<String,Object>)System.Json.deserializeUntyped(messages[0].Event__c);
            actualHops = (Integer) actualEvent.get('__Hops');
            
            //assemble
            Map<String,Object> ex = (Map<String,Object>)Json.deserializeUntyped(messages[0].Cause__c);
            actualDetail = (String)ex.get('Message');
            actualStatus = messages[0].Status__c;
        }
   
        // assert
        Integer expectedCount = 1;
        System.assertEquals( expectedCount, actualCount);
        Integer expectedHops = maxHops;
        System.assertEquals(expectedHops, actualHops, 'Wrong hops.');
        
        String expectedDetail = 'Too many hops - to resolve, manually set __Hops on event parameters to 0';
        System.assertEquals(expectedDetail, actualDetail, 'Wrong message');
        
        String expectedStatus = 'Started';
        System.assertEquals(expectedStatus, actualStatus, 'Wrong message status.');
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
        
        Step__c terminateStep = StepModel.generateOne(sequence.Name, Terminate.class.getName());
        
        //arrange message
        Broker.MaxHops = 1;
        List<Message__c> messages = new Job(new Map<String,Object>{
            'esb__SequenceName' => 'Test'
            //'esb__Hops' => 0 //enqueue sets hops
        }).persist();
        
        //assemble
        //http://salesforce.stackexchange.com/q/61213/320
        messages = ApexDomain.listAll(Message__c.SObjectType);
        
        Boolean actualFlag = false;
        
        //act
        Broker.impl().execute(messages, new List<Message__c>());
        
        //assemble
        //messages = [SELECT Exception__c FROM Message__c WHERE Id = :messages[0].Id];
        actualFlag = messages[0].Exception__c != null;

        //assert
        Boolean expectedFlag = true;
        System.assertEquals( expectedFlag, actualFlag);
    }
    
    
    static testmethod void canCorrectlyIncrementAndPersistMessages() {
        //arrange sequence
        String sequenceNameA = 'sequenceA';
        Sequence__c sequenceA = new Sequence__c(Name = sequenceNameA);
        insert sequenceA;
        
        //arrange steps
        Step__c stepA1 = StepModel.generateOne(sequenceA.Name, Subscribe.class.getName());
        Step__c stepA2 = StepModel.generateOne(sequenceA.Name, Publish.class.getName());
        Step__c stepA3 = StepModel.generateOne(sequenceA.Name, Terminate.class.getName());
        Decimal positionA1 = stepA1.Position__c;
        Decimal positionA2 = stepA2.Position__c;
        Decimal positionA3 = stepA3.Position__c;
        
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
        
        Decimal expectedPosition1 = positionA1 + 1;
        Decimal actualPosition1 = (Decimal)inputEvent1.get('__Position');
        System.assertEquals(expectedPosition1, actualPosition1, 'Wrong position 1.');

        String expectedSequenceName2 = 'sequenceName2';
        String actualSequenceName2 = (String)inputEvent2.get('__SequenceName');
        System.assertEquals(expectedSequenceName2, actualSequenceName2, 'Wrong sequence name');
        
        Decimal expectedPosition2 = positionA2 + 1;
        Decimal actualPosition2 = (Decimal)inputEvent2.get('__Position');
        System.assertEquals(expectedPosition2, actualPosition2, 'Wrong position 2.');
    }
    
    static testmethod void testLocatorMarksCorrectNumberOfMessages() {
        //arrange
        Sequence__c sequence = new Sequence__c(Name = 'test');
        insert sequence;
        
        Step__c terminateStep = StepModel.generateOne(sequence.Name, Terminate.class.getName());
        
        new Job(new List<Map<String,Object>>{
            new Map<String,Object>{'__SequenceName' => 'test', '__Position' => 1},
            new Map<String,Object>{'__SequenceName' => 'test', '__Position' => 1},
            new Map<String,Object>{'__SequenceName' => 'test', '__Position' => 1}
        }).persist();
        
        //act
        MockBroker broker = new MockBroker();
        
        //MARK
        List<Message__c> messages = broker.locateMarkableWork();
        
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
        
        Step__c terminateStep = StepModel.generateOne(sequence.Name, Terminate.class.getName());
        
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
        MockBroker broker = new MockBroker();
        
        //MARK
        List<Message__c> messages = broker.locateMarkableWork();
        
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
        Step__c stepA1 = StepModel.generateOne(sequenceA.Name, Subscribe.class.getName());
        Step__c stepA2 = StepModel.generateOne(sequenceA.Name, Publish.class.getName());
        Step__c stepA3 = StepModel.generateOne(sequenceA.Name, Terminate.class.getName());
        Step__c stepB1 = StepModel.generateOne(sequenceB.Name, Wiretap.class.getName());
        Step__c stepB2 = StepModel.generateOne(sequenceB.Name, Terminate.class.getName());
        Step__c stepC1 = StepModel.generateOne(sequenceC.Name, Publish.class.getName());
        Step__c stepC2 = StepModel.generateOne(sequenceC.Name, Terminate.class.getName());
        
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
        StepModel.generateOne(sequence.Name, Terminate.class.getName());
        
        //arrange broker implementation custom setting
        String theSequenceName = 'TestSequence';
        Id theId = '000000000000000AAA';
        insert new BrokerSetting__c(BrokerClassName__c = BrokerTest.MockBroker.class.getName());
        
        //assert
        Boolean expectedBeforeFlag = false;
        Boolean actualBeforeFlag = BrokerTest.flagrunImpl;
        System.assertEquals(expectedBeforeFlag, actualBeforeFlag);
        
        //IT'S a @FUTURE CALL ... dont want that to happen every time
        
        //act
        new Job(theSequenceName, theId).execute(null);
        
        //assert
        Boolean expectedAfterFlag = true;
        Boolean actualAfterFlag = flagrunImpl;
        System.assertEquals(expectedAfterFlag, actualAfterFlag);
    }
    
    static testmethod void callingEnqueueSuccessfullyCallEnqueueImpAndCreatesDocument() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange steps
        StepModel.generateOne(sequence.Name, Terminate.class.getName());
        
        //arrange
        insert new BrokerSetting__c(BrokerClassName__c = BrokerTest.MockBroker.class.getName());
        
        //assert
        Boolean expectedBeforeFlag = false;
        Boolean actualBeforeFlag = BrokerTest.flagrunImpl;
        System.assertEquals(expectedBeforeFlag, actualBeforeFlag);
        
        Integer expectedSizeBefore = 0;
        Integer actualSizeBefore = [SELECT COUNT() FROM Document];
        System.assertEquals(expectedSizeBefore , actualSizeBefore);
        
        //act
        new Job('TestSequence', Blob.valueOf('balls')).execute(null);
        
        //assert
        Integer expectedSizeAfter = 1;
        Integer actualSizeAfter = [SELECT COUNT() FROM Document];
        System.assertEquals(expectedSizeAfter, actualSizeAfter);
        
        Boolean expectedAfterFlag = true;
        Boolean actualAfterFlag = BrokerTest.flagrunImpl;
        System.assertEquals(expectedAfterFlag, actualAfterFlag);
    }
    
    static testmethod void callingRestartSuccessfullyCallsrunImpl() {
        //arrange
        insert new BrokerSetting__c(BrokerClassName__c = BrokerTest.MockBroker.class.getName());
        List<Message__c> messages = new Job('test', UserInfo.getUserId()).persist();
        
        //assert
        Boolean expectedBeforeFlag = false;
        Boolean actualBeforeFlag = flagrunImpl;
        System.assertEquals(expectedBeforeFlag, actualBeforeFlag);
        
        //act
        Broker.run();
        
        //assert
        Boolean expectedAfterFlag = true;
        Boolean actualAfterFlag = flagrunImpl;
        System.assertEquals(expectedAfterFlag, actualAfterFlag);
        
    }

    
    /**
     * Bug with Salesforce:
     * We cannot legitimately test for recycle bin purges - See Andy Fawcett's stackexchange comment:
     * http://salesforce.stackexchange.com/questions/27180/database-emptyrecyclebin-exhibits-unexpected-behaviour
     */
    
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
        Broker broker = new DoNothingBroker();
        
        String actualMessage;
        
        //act
        broker.execute(messages, new List<Message__c>());
        
        //assemble
        actualMessage = messages[0].Exception__c;
        
        //assert
        String expectedMessage = 'Mandatory event parameter esb__SequenceName not supplied.';
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
        Broker broker = new DoNothingBroker();
        
        String actualMessage;
        
        //act
        broker.execute(messages, new List<Message__c>());
        
        //assemble
        actualMessage = messages[0].Exception__c;
        
        //assert
        String expectedMessage = 'Step unqueryable, eg bad sequence name, position, missing terminate.';
        System.assertEquals(expectedMessage, actualMessage, 'Wrong message.');
    }
    
    static testmethod void testProcessWithoutClassThrowsExpectedException() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange steps
        Step__c step = StepModel.generateOne(sequence.Name, Terminate.class.getName());
        step.FullyQualifiedClassName__c = 'lalala';
        update step;
        
        //arrange specific broker implementation
        insert new BrokerSetting__c(BrokerClassName__c = SynchronousBroker.class.getName());
        
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
    
    static testmethod void callingEnqueueWhenBrokerIsPausedQueuesMessageWithStatusQueued() {
        // arrange
        Boolean isPaused =  true;

        String sequenceNameA = 'sequenceA';
        Sequence__c sequenceA = new Sequence__c(Name = sequenceNameA);
        insert sequenceA;


        Integer positionA1 = 1;
        Integer positionA6 = 2;

        Step__c stepA1 = StepModel.generateOne(sequenceA.Name, Wiretap.class.getName());
        Step__c stepA6 = StepModel.generateOne(sequenceA.Name, Terminate.class.getName());

        //arrange specific broker implementation
        insert new BrokerSetting__c(BrokerClassName__c = SynchronousBroker.class.getName(), IsPaused__c = isPaused);
        //insert new BrokerSetting__c();

        //act
        new Job(sequenceNameA, '000000000000000AAA').execute(null);


        //assemble
        List<Message__c> messages = [
            SELECT Id, Name, Event__c, Status__c
            FROM Message__c
            WHERE Status__c != 'Completed'
        ];


        String actualStatus;
        Integer actualCount = messages.size();
        if (actualCount > 0) {
            actualStatus = messages[0].Status__c;
        }

        // assert
        Integer expectedCount = 1;
        System.assertEquals( expectedCount, actualCount);
        String expectedStatus = 'Queued';
        System.assertEquals( expectedStatus, actualStatus);
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

        Step__c stepA1 = StepModel.generateOne(sequenceA.Name, Wiretap.class.getName());
        Step__c stepA2 = StepModel.generateOne(sequenceA.Name, Wiretap.class.getName());
        Step__c stepA3 = StepModel.generateOne(sequenceA.Name, Wiretap.class.getName());
        Step__c stepA4 = StepModel.generateOne(sequenceA.Name, Wiretap.class.getName());
        Step__c stepA5 = StepModel.generateOne(sequenceA.Name, Wiretap.class.getName());
        Step__c stepA6 = StepModel.generateOne(sequenceA.Name, Terminate.class.getName());

        //arrange specific broker implementation
        insert new BrokerSetting__c(BrokerClassName__c = SynchronousBroker.class.getName(), IsPaused__c = isPaused);
        
        //act
        new Job(sequenceNameA, '000000000000000AAA').execute(null);

        
        //assemble
        List<Message__c> messages = [
            SELECT Id, Name, Event__c, Status__c
            FROM Message__c
            WHERE Status__c = 'Completed'
        ];

        Integer actualCount = messages.size();

   
        // assert
        Integer expectedCount = 6;
        System.assertEquals( expectedCount, actualCount);
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

        Step__c stepA1 = StepModel.generateOne(sequenceA.Name, Wiretap.class.getName());
        Step__c stepA2 = StepModel.generateOne(sequenceA.Name, Wiretap.class.getName());
        Step__c stepA3 = StepModel.generateOne(sequenceA.Name, Wiretap.class.getName());
        Step__c issue = StepModel.generateOne(sequenceA.Name, Wiretap.class.getName()); // deleted - implying a resolution issue
        Step__c stepA5 = StepModel.generateOne(sequenceA.Name, Wiretap.class.getName());
        Step__c stepA6 = StepModel.generateOne(sequenceA.Name, Terminate.class.getName());
        
        delete issue;
        
        //arrange specific broker implementation
        insert new BrokerSetting__c(BrokerClassName__c = SynchronousBroker.class.getName(), IsPaused__c = false);
        
        //act
        new Job(sequenceNameA, '000000000000000AAA').execute(null);

        
        //assemble
        List<Message__c> messagesOk = [
            SELECT Id, Name, Event__c, Status__c, Cause__c
            FROM Message__c
            WHERE Status__c = 'Completed'
        ];
        List<Message__c> messagesFailed = [
            SELECT Id, Name, Event__c, Status__c, Cause__c
            FROM Message__c
            WHERE Status__c = 'Started'
        ];
        
        //assert
        Integer actualCountOk = messagesOk.size();
        Integer expectedCountOk = 3;
        System.assertEquals( expectedCountOk, actualCountOk);
        
        Integer actualCountFailed = messagesFailed.size();
        Integer expectedCountFailed = 1;
        System.assertEquals( expectedCountFailed, actualCountFailed);
        
        //assemble
        Map<String,Object> actualException = (Map<String,Object>)Json.deserializeUntyped(messagesFailed[0].Cause__c);

        // assert
        String expectedExceptionMessage = 'Step unqueryable, eg bad sequence name, position, missing terminate.';
        String actualExceptionMessage = (String)actualException.get('Message');
        System.assertEquals(expectedExceptionMessage, actualExceptionMessage, 'Wrong message');
    }
 
    static testMethod void callingEnqueueWithEventParametersIncludesAllEventParametersInMessage() {
        // arrange
        String sequenceName = 'Test';
        Sequence__c sequence = new Sequence__c(Name = sequenceName);
        insert sequence;
        
        Integer position = 1;
        Step__c step = StepModel.generateOne(sequence.Name, Terminate.class.getName());
  
        insert new BrokerSetting__c(BrokerClassName__c = SynchronousBroker.class.getName());
        
        String eventStamp = HeartbeatImplementation.getISO8601(DateTime.newInstance(2014,12,15,13,11,07));
        Map<String,Object> inputEvent = new Map<String,Object>{
            'esb__Id' => UserInfo.getUserId(),
            '__SequenceName' => sequenceName,
            '__Position' => position,
            'esb__EntryPointDatetime' => eventStamp
        };
             
        // act
        new Job(inputEvent).execute(null);

        // assemble
        List<Message__c> actualMessages = [  SELECT  Id, Event__c FROM Message__c];
        Integer actualCount  = actualMessages.size();
        String  actualEventStamp;
        if (actualCount == 1) {
            Map<String,Object> actualEvent = (Map<String,Object>)Json.deserializeUntyped(actualMessages[0].Event__c);
            actualEventStamp = (String)actualEvent.get('esb__EntryPointDatetime');
        }
 
        // assert
        Integer expectedCount  = 1;
        System.assertEquals(expectedCount, actualCount);
        String  expectedEventStamp = eventStamp;
        System.assertEquals(expectedEventStamp, actualEventStamp);
    }

    static testMethod void callingExecuteWithoutMandatoryEventParametersInEventParametersCollectionThrowsException() {
        // arrange process, sequence, step
        String sequenceName = 'Test';
        Sequence__c sequence = new Sequence__c(Name = sequenceName);
        insert sequence;
        
        Step__c step = StepModel.generateOne(sequence.Name, Terminate.class.getName());
  
        //arrange broker
        insert new BrokerSetting__c(BrokerClassName__c = SynchronousBroker.class.getName());
        
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
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange steps
        StepModel.generateOne(sequence.Name, Terminate.class.getName());
        
        //arrange specific broker implementation
        insert new BrokerSetting__c(BrokerClassName__c = SynchronousBroker.class.getName());
        
        //act
        new Job(sequence.Name, '000000000000000AAA').execute(null);
        
        // assemble
        List<Message__c> messagesAfter = [SELECT Event__c FROM Message__c LIMIT 1];
        
        
        String  actualEntryPointUuid ;
        Id      actualEnqueueUserId  ;
        Integer actualPosition       ;
        if (messagesAfter.size() == 1) {
            Map<String,Object> inputEvent = (Map<String,Object>)Json.deserializeUntyped(messagesAfter[0].Event__c);
            actualEntryPointUuid = (String) inputEvent.get('__EntryPointUuid');
            actualEnqueueUserId  = (Id) inputEvent.get('__EnqueueUserId' );
            actualPosition       = (Integer) inputEvent.get('__Position');
        }

        // assert
        String  expectedEntryPointUuid = null;
        System.assertNotEquals(expectedEntryPointUuid,actualEntryPointUuid);
        Id  expectedEnqueueUserId = UserInfo.getUserId();
        System.assertEquals(expectedEnqueueUserId,actualEnqueueUserId);
        Integer expectedPosition = 1;
        System.assertEquals(expectedPosition ,actualPosition);
    }

    static testMethod void callingInvokeMainWithCorrectToToStringOverrideDoesNOTThrowException() {
        //arrange
        Map<String,Object> inputEvent = new Map<String,Object>();
        
        //act
        Boolean actualFlag = true;
        Type reflector = Terminate.class;
        try {
            Broker.Wrapper wrapper = new Broker.Wrapper(reflector, inputEvent).invokeMain();
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
            Broker.Wrapper wrapper = new Broker.Wrapper(reflector, inputEvent).invokeMain();
            System.assert(false, 'Above should throw exception.');
        } catch (Broker.EngineException e) {
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
    
    @TestVisible public class ChunkErrorProcess {
        
        @TestVisible public String Event;
        
        override public String toString() {
            Map<String,Object> inputEvent = (Map<String,Object>)Json.deserializeUntyped(this.Event);
            Boolean isError = (Boolean)inputEvent.get('c__IsError');
            if (isError == true) throw new ChunkErrorProcessException('Test error');
            return '[{}]'; //one message
        }
        
    }
    
    @TestVisible public class ChunkErrorProcessESB {
        public String Description = 'Process used for testing kamikaze chunking solution.';
    }
    
    static testmethod void testKamikazeChunkingDoesntTakeOutHisMates() {
        //arrange processes, sequence and steps
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        Step__c errorStep = StepModel.generateOne(sequence.Name, ChunkErrorProcess.class.getName());
        Step__c terminateStep = StepModel.generateOne(sequence.Name, Terminate.class.getName());
        
        //arrange broker implementation and params
        insert new BrokerSetting__c(BrokerClassName__c = SynchronousBroker.class.getName());
        Map<String,Object> failureEvent = new Map<String,Object>{'c__IsError' => true, '__SequenceName' => 'Test', '__Position' => 1};
        Map<String,Object> successEvent = new Map<String,Object>{'c__IsError' => false, '__SequenceName' => 'Test', '__Position' => 1};
        List<Map<String,Object>> events = new List<Map<String,Object>>{failureEvent, successEvent};
        
        //arrange messages and broker
        List<Message__c> messages = new Job(events).persist();
        Broker impl = Broker.impl();
        
        List<Message__c> outputMessages = new List<Message__c>();
        //act
        impl.execute(messages, outputMessages);
        //#798 should only have one message
        Integer expectedCount = 1;
        Integer actualCount = outputMessages.size();
        System.assertEquals(expectedCount, actualCount);
        
    }
    
}