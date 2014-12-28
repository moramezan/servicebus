@IsTest public class BrokerTest { //formerly FailureProcess
    
    public String Parameters;
    
    @TestVisible private class ESB {
        public String Tag = 'Enterprise Service Bus';
        public String Name = 'Failure Process';
        public String Description = 'A toStringable Object that throws an exception for testing purposes.'; //Will not be listed
    }
    
    override public String toString() {
        Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(this.Parameters);
        throw new BrokerException(FailureMessage);
        return Json.serialize(new List<Map<String,Object>>{parameters});
    }
    
    public class BrokerException extends Exception {}

    public class DoNothingBroker extends Broker {
        override public void restartImpl() {}
        override public Boolean isAlreadyRunning() {return true;}
    }
    
    @TestVisible static private String FailureMessage = 'Fake Error Thrown in FailureProcess';
    
    static public Boolean flagRestartImpl = false;
    public class MockBroker extends Broker {
        override public Boolean isAlreadyRunning() {
            return false;
        }
        
        override public void restartImpl() {
            flagRestartImpl = true;
        }
    }

    static testmethod void testChunkingMarkFindsMultipleWork() {
        //arrange broker
        insert new BrokerSetting__c(BrokerClassName__c = SynchronousBroker.class.getName());
        
        //arrange processes and sequence and steps
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        
        Sequence__c sequence = new Sequence__c(Name = 'test');
        insert sequence;
        
        Step__c wiretapStep = StepObject.generateOne(sequence.Id, wiretapProcess.Id);
        Step__c terminateStep = StepObject.generateOne(sequence.Id, terminateProcess.Id);
        
        //arrange messages
        String parameters = '{"__SequenceName":"test","__Position":1}';
        List<Message__c> messages = new List<Message__c>{
            new Message__c(Parameters__c = parameters),
            new Message__c(Parameters__c = parameters),
            new Message__c(Parameters__c = parameters),
            new Message__c(Parameters__c = parameters),
            new Message__c(Parameters__c = parameters),
            new Message__c(Parameters__c = parameters),
            new Message__c(Parameters__c = parameters),
            new Message__c(Parameters__c = parameters),
            new Message__c(Parameters__c = parameters)
        };
        
        insert messages;
        
        //act
        Database.QueryLocator locator = Broker.impl().locateMarkableWork();
        List<Message__c> records = new ApexPages.StandardSetController(locator).getRecords();
        
        //assert
        Integer expectedLimits = 9;
        Integer actualLimits = new Wiretap.ESB().Limits;
        System.assertEquals(expectedLimits, actualLimits, 'Wiretap should have meta limits of nine.');
        
        Integer expectedSize = 9;
        Integer actualSize = records.size();
        System.assertEquals(expectedSize, actualSize, 'Chunking mark should have found nine.');
    }
    

    static testmethod void hopsExceededWillHaltStartedWithAppropriateMessageDetail() {
        // arrange
        Integer maxHops = 3;
        Broker.MaxHops = maxHops;

        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);

        String sequenceNameA = 'sequenceA';
        Sequence__c sequenceA = new Sequence__c(Name = sequenceNameA);
        insert sequenceA;


        Integer positionA1 = 1;
        Integer positionA2 = 2;
        Integer positionA3 = 3;
        Integer positionA4 = 4;
        Integer positionA5 = 5;
        Integer positionA6 = 6;

        Step__c stepA1 = new Step__c(Sequence__c = sequenceA.Id ,Position__c = positionA1,Process__c = wiretapProcess.Id);
        Step__c stepA2 = new Step__c(Sequence__c = sequenceA.Id ,Position__c = positionA2,Process__c = wiretapProcess.Id);
        Step__c stepA3 = new Step__c(Sequence__c = sequenceA.Id ,Position__c = positionA3,Process__c = wiretapProcess.Id);
        Step__c stepA4 = new Step__c(Sequence__c = sequenceA.Id ,Position__c = positionA4,Process__c = wiretapProcess.Id);
        Step__c stepA5 = new Step__c(Sequence__c = sequenceA.Id ,Position__c = positionA5,Process__c = wiretapProcess.Id);
        Step__c stepA6 = new Step__c(Sequence__c = sequenceA.Id ,Position__c = positionA6,Process__c = terminateProcess.Id);

        insert stepA1;
        insert stepA2;
        insert stepA3;
        insert stepA4;
        insert stepA5;
        insert stepA6;
        
        //arrange specific broker implementation
        insert new BrokerSetting__c(BrokerClassName__c = SynchronousBroker.class.getName());
        
        //act 
        Broker.enqueue(sequenceNameA, '000000000000000AAA');

        
        //assemble
        List<Message__c> messages = [
            SELECT Id, Name, Parameters__c, Status__c, Cause__c
            FROM Message__c
            WHERE Status__c != 'Completed'
        ];
        
        Integer actualHops;
        String actualDetail;
        String actualStatus;
        Integer actualCount = messages.size();
        if (actualCount > 0) {
            Map<String,Object> actualParameters = (Map<String,Object>)System.Json.deserializeUntyped(messages[0].Parameters__c);
            actualHops = (Integer) actualParameters.get('__Hops');
            
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
        
        String expectedDetail = 'Too many hops - to resolve, manually set __Hops on parameters to 0';
        System.assertEquals(expectedDetail, actualDetail, 'Wrong message');
        
        String expectedStatus = 'Started';
        System.assertEquals(expectedStatus, actualStatus, 'Wrong message status.'); 
    }
    
    static testmethod void callingEnforceMaxHopsReturnsExpectedValueWhenHopsParameterLtThreshold() {
        //arrange
        Map<String,Object> parameters = new Map<String,Object>();
        Integer threshold = 10;
        Integer hops = 8;
        String key  = '__Hops';
        parameters.put(key, hops);
        
        //act
        Integer actualHops = Broker.enforceMaxHops(parameters, threshold);

        //assert
        Integer expectedHops = hops + 1;
        System.assertEquals( expectedHops, actualHops);
    }



    static testmethod void callingEnforceMaxHopsReturnsExpectedValueWhenHopsParameterNotDefined() {
       //arrange
        Map<String,Object> parameters = new Map<String,Object>();
        Integer threshold = 10;
        Integer hops = 1;

        //act
        Integer actualHops = Broker.enforceMaxHops(parameters, threshold);

        //assert
        Integer expectedHops = hops + 1;
        System.assertEquals( expectedHops, actualHops);
    }
 
  
    static testmethod void callingEnforceMaxHopsThrowsExceptionWhenHopsParameterGtOrEqToThreshold() {
       //arrange
        Map<String,Object> parameters = new Map<String,Object>();
        Integer threshold = 10;
        Integer hops = 10;
        String key  = '__Hops';
        parameters.put(key, hops);
        
        Boolean actualFlag = false;
        try {
            //act
            Integer actualHops = Broker.enforceMaxHops(parameters, threshold);
        } catch (Broker.TooManyHopsException e) {
            actualFlag = true;
        }

        //assert
        Boolean expectedFlag = true;
        System.assertEquals( expectedFlag, actualFlag);
    }
    
    
    static testmethod void callingApplyHopsCorrectlyAppliesHopsToParameters() {
        //arrange
        Integer hops = 8;
        Map<String,Object> parameters = new Map<String,Object>();
        List<Map<String,Object>>  parametersList = new List<Map<String,Object>>{ parameters };

        //act
        parametersList = new DoNothingBroker().applyHops(parametersList, hops);

        //assemble
        Integer actualHops = -1;
        List<Map<String,Object>>  actualParametersList = parametersList;
        for (Map<String,Object> actualParameters : actualParametersList ) {
            actualHops = (Integer) actualParameters.get('__Hops');
        }
 
        //assert
        Integer expectedhops = hops;
        System.assertEquals(expectedHops, actualHops);
    }
    
 

    static testmethod void canCorrectlyIncrementAndPersistMessages() {
        //arrange processes
        Process__c markProcess = ProcessObject.generateOne(Mark.class);
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        Process__c subscribeProcess = ProcessObject.generateOne(Subscribe.class);
        
        //arrange sequence
        String sequenceNameA = 'sequenceA';
        Sequence__c sequenceA = new Sequence__c(Name = sequenceNameA);
        insert sequenceA;
        
        //arrange steps
        Step__c stepA1 = StepObject.generateOne(sequenceA.Id, subscribeProcess.Id);
        Step__c stepA2 = StepObject.generateOne(sequenceA.Id, markProcess.Id);
        Step__c stepA3 = StepObject.generateOne(sequenceA.Id, terminateProcess.Id);
        Decimal positionA1 = stepA1.Position__c;
        Decimal positionA2 = stepA2.Position__c;
        Decimal positionA3 = stepA3.Position__c;
        
        List<Message__c> messages =  new List<Message__c>{
            new Message__c(Parameters__c = '{"__SequenceName": "' + sequenceNameA + '", "__Position": ' + positionA1 + '}'),
            new Message__c(Parameters__c = '{"__SequenceName": "' + sequenceNameA + '", "__Position": ' + positionA2 + '}')
        };
        
        
        //act
        new MessageObjectSet(messages).incrementPositions();
        insert messages;
        
        // assemble
        List<Message__c> messagesAfter = SalesforceObjectSet.listAll(Message__c.SObjectType);
        
        Boolean flagPosition01 = false;
        Boolean flagPosition02 = false;
        Boolean flagSequenceNameA = true;
        for (Message__c message : messagesAfter) {
            Map<String,Object> parameters = (Map<String,Object>)System.Json.deserializeUntyped(message.Parameters__c);
            String parametersSequenceName = (String)parameters.get('__SequenceName');
            Integer parametersPosition = (Integer)parameters.get('__Position');
            if (parametersSequenceName != sequenceNameA) {
                flagSequenceNameA = false;
            }
            if (parametersPosition == (positionA1 + 1))  {
                flagPosition01 = true;
            }
            if (parametersPosition == (positionA2 + 1))  {
                flagPosition02 = true;
            }
        }
        
        // assert
        Integer expectedCount = 2;
        Integer actualCount = messagesAfter.size();
        System.assertEquals(expectedCount, actualCount);

        System.assert(flagSequenceNameA);
        System.assert(flagPosition01);
        System.assert(flagPosition02);

        Id expectedStepId01 = stepA2.Id;
        Id expectedStepId02 = stepA3.Id ;
        Id expectedProcessId01 = markProcess.Id;
        Id expectedProcessId02 = terminateProcess.Id;
    }
    
    static testmethod void testLocatorMarksCorrectNumberOfMessages() {
        //arrange
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        
        Sequence__c sequence = new Sequence__c(Name = 'test');
        insert sequence;
        
        Step__c terminateStep = StepObject.generateOne(sequence.Id, terminateProcess.Id);
        
        insert new List<Message__c>{
            new Message__c(Parameters__c = '{"__SequenceName":"test","__Position":1}'),
            new Message__c(Parameters__c = '{"__SequenceName":"test","__Position":1}'),
            new Message__c(Parameters__c = '{"__SequenceName":"test","__Position":1}')
        };
        
        //act
        MockBroker broker = new MockBroker();
        Database.QueryLocator locator = broker.locateMarkableWork();
        Database.QueryLocatorIterator iterator = locator.iterator();
        
        //MARK
        broker.mark(new ApexPages.StandardSetController(locator).getRecords());
        
        List<Message__c> messages = new List<Message__c>();
        while (iterator.hasNext()) messages.add((Message__c)iterator.next());
        
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
        Database.QueryLocatorIterator iterator = new MockBroker().locateMarkableWork().iterator();
        List<Message__c> messages = new List<Message__c>();
        while (iterator.hasNext()) messages.add((Message__c)iterator.next());
        
        //assert
        Integer expectedCount = 0;
        Integer actualCount = messages.size();
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testmethod void testLocatorReturnsOnlyRebufferedWork() {
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        
        Sequence__c sequence = new Sequence__c(Name = 'test');
        insert sequence;
        
        Step__c terminateStep = StepObject.generateOne(sequence.Id, terminateProcess.Id);
        
        //arrange fucked messages
        insert new List<Message__c>{
            new Message__c(Status__c = 'Started', Parameters__c = '{"__SequenceName":"test","__Position":1}'),
            new Message__c(Status__c = 'Started', Parameters__c = '{"__SequenceName":"test","__Position":1}')
        };
        
        //arrange Rebuffered messages
        insert new List<Message__c>{
            new Message__c(Status__c = 'Rebuffered', Parameters__c = '{"__SequenceName":"test","__Position":1}'),
            new Message__c(Status__c = 'Rebuffered', Parameters__c = '{"__SequenceName":"test","__Position":1}')
        };
        
        //act
        MockBroker broker = new MockBroker();
        Database.QueryLocator locator = broker.locateMarkableWork();
        Database.QueryLocatorIterator iterator = locator.iterator();
        
        //MARK
        broker.mark(new ApexPages.StandardSetController(locator).getRecords());
        
        List<Message__c> messages = new List<Message__c>();
        while (iterator.hasNext()) messages.add((Message__c)iterator.next());
        
        // assert
        Integer expectedCount = 2;
        Integer actualCount = messages.size();
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testmethod void canCorrectlyIncrementMessages() {
        // arrange
        Process__c markProcess = ProcessObject.generateOne(Mark.class);
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);
        Process__c subscribeProcess = ProcessObject.generateOne(Subscribe.class);

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
        Step__c stepA1 = new Step__c(Sequence__c = sequenceA.Id ,Position__c = positionA1,Process__c = subscribeProcess.Id);
        Step__c stepA2 = new Step__c(Sequence__c = sequenceA.Id ,Position__c = positionA2,Process__c = markProcess.Id);
        Step__c stepA3 = new Step__c(Sequence__c = sequenceA.Id ,Position__c = positionA3,Process__c = terminateProcess.Id);
        Step__c stepB1 = new Step__c(Sequence__c = sequenceB.Id ,Position__c = positionB1,Process__c = wiretapProcess.Id);
        Step__c stepB2 = new Step__c(Sequence__c = sequenceB.Id ,Position__c = positionB2,Process__c = terminateProcess.Id);
        Step__c stepC1 = new Step__c(Sequence__c = sequenceC.Id ,Position__c = positionC1,Process__c = markProcess.Id);
        Step__c stepC2 = new Step__c(Sequence__c = sequenceC.Id ,Position__c = positionC2,Process__c = terminateProcess.Id);
        insert stepA1;
        insert stepA2;
        insert stepA3;
        insert stepB1;
        insert stepB2;
        insert stepC1;
        insert stepC2;
        
        List<Message__c> messages = new List<Message__c>{
            new Message__c(Parameters__c = '{"esb__Id": 0, "__SequenceName": "' + sequenceA.Name + '", "__Position": ' + positionA1 + '}'), // Same Sequence / Position
            new Message__c(Parameters__c = '{"esb__Id": 1, "__SequenceName": "' + sequenceA.Name + '", "__Position": ' + positionA1 + '}'), // Same Sequence / Position
            new Message__c(Parameters__c = '{"esb__Id": 2, "__SequenceName": "' + sequenceA.Name + '", "__Position": ' + positionA2 + '}'),
            new Message__c(Parameters__c = '{"esb__Id": 3, "__SequenceName": "' + sequenceB.Name + '", "__Position": ' + positionB1 + '}'),
            new Message__c(Parameters__c = '{"esb__Id": 4, "__SequenceName": "' + sequenceC.Name + '", "__Position": ' + positionC1 + '}')
        };
        
        // act
        new MessageObjectSet(messages).incrementPositions();
        insert messages;
        
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
            Map<String,Object> parameters = (Map<String,Object>)System.Json.deserializeUntyped(message.Parameters__c);
            Integer theId = (Integer) parameters.get('esb__Id');
            String theSequenceName = (String)parameters.get('__SequenceName');
            Integer thePosition = (Integer)parameters.get('__Position');
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
    
    static testmethod void callingEnqueueSuccessfullyCallsRestartImpl() {
        //arrange processes
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange steps
        StepObject.generateOne(sequence.Id, terminateProcess.Id);
        
        //arrange broker implementation custom setting
        String theSequenceName = 'TestSequence';
        Id theId = '000000000000000AAA';
        insert new BrokerSetting__c(BrokerClassName__c = BrokerTest.MockBroker.class.getName());
        
        //assert
        Boolean expectedBeforeFlag = false;
        Boolean actualBeforeFlag = BrokerTest.flagRestartImpl;
        System.assertEquals(expectedBeforeFlag, actualBeforeFlag);
        
        //act
        Broker.enqueue(theSequenceName, theId);
        
        //assert
        Boolean expectedAfterFlag = true;
        Boolean actualAfterFlag = flagRestartImpl;
        System.assertEquals(expectedAfterFlag, actualAfterFlag);
    }
    
    static testmethod void callingEnqueueSuccessfullyCallEnqueueImpAndCreatesDocument() {
        //arrange processes
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange steps
        StepObject.generateOne(sequence.Id, terminateProcess.Id);
        
        //arrange
        insert new BrokerSetting__c(BrokerClassName__c = BrokerTest.MockBroker.class.getName());
        
        //assert
        Boolean expectedBeforeFlag = false;
        Boolean actualBeforeFlag = BrokerTest.flagRestartImpl;
        System.assertEquals(expectedBeforeFlag, actualBeforeFlag);
        
        Integer expectedSizeBefore = 0;
        Integer actualSizeBefore = [SELECT COUNT() FROM Document];
        System.assertEquals(expectedSizeBefore , actualSizeBefore);
        
        //act
        Broker.enqueue('TestSequence', Blob.valueOf('balls'));
        
        //assert
        Integer expectedSizeAfter = 1;
        Integer actualSizeAfter = [SELECT COUNT() FROM Document];
        System.assertEquals(expectedSizeAfter, actualSizeAfter);
        
        Boolean expectedAfterFlag = true;
        Boolean actualAfterFlag = BrokerTest.flagRestartImpl;
        System.assertEquals(expectedAfterFlag, actualAfterFlag);
    }
    
    static testmethod void callingRestartSuccessfullyCallsRestartImpl() {
        //arrange
        insert new BrokerSetting__c(BrokerClassName__c = BrokerTest.MockBroker.class.getName());
        insert new Message__c(Status__c = 'Rebuffered');
        
        //assert
        Boolean expectedBeforeFlag = false;
        Boolean actualBeforeFlag = flagRestartImpl;
        System.assertEquals(expectedBeforeFlag, actualBeforeFlag);
        
        //act
        new MockBroker().restartIfWorkPending();
        
        //assert
        Boolean expectedAfterFlag = true;
        Boolean actualAfterFlag = flagRestartImpl;
        System.assertEquals(expectedAfterFlag, actualAfterFlag);
        
    }
    
      static testmethod void callingGateHelperCorrectlySetsCountOnParametersWhenMarkCountIncrementsTo1() {
        //arrange
        Integer markCount = 0;
        Map<String,Object> parametersIn0 = new Map<String,Object> {
            'esb__Id' => '0',
            '__MarkCount' => markCount
        };
        
        Map<String,Object> parametersOut1 = new Map<String,Object> {
            'esb__Id' => '1'
        };
        
        Map<String,Object> parametersOut2 = new Map<String,Object> {
            'esb__Id' => '2'
        };
        
        Map<String,Object> parametersOut3 = new Map<String,Object> {
            'esb__Id' => '3'
        };
        
        List<Map<String,Object>> parametersListOut = new List<Map<String,Object>> { parametersOut1, parametersOut2, parametersOut3 };
        
        //act
        new DoNothingBroker().gateHelper(parametersIn0, parametersListOut);
        
        //assemble
        Integer actualCount = (Integer)parametersListOut[0].get('__Count');
        
        //assert
        Integer expectedCount = parametersListOut.size();
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testmethod void callingGateHelperDoesNotSetCountOnParametersWhenMarkCountIncrementsToOtherThan1() {
        //arrange
        Integer markCount = 0; //will not increment to 1
        Map<String,Object> parametersIn0 = new Map<String,Object> {
            'esb__Id' => '0',
            '__MarkCount' => markCount
        };
        
        List<Map<String,Object>> parametersListOut = new List<Map<String,Object>>();
        
        //act
        new DoNothingBroker().gateHelper(parametersIn0, parametersListOut);
        
        //assemble
        Integer actualCount = (Integer)parametersIn0.get('__Count');
        
        //assert
        Integer expectedCount = null;
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testmethod void callingGateHelperDoesNotSetCountOnParametersWhenMarkCountIsNull() {
        //arrange
        Map<String,Object> parametersIn0 = new Map<String,Object> {
            'esb__Id' => '0'
            //'__MarkCount' => markCount //Not specified; key will return null
        };
        
        List<Map<String,Object>> parametersListOut = new List<Map<String,Object>>();
        
        //act
        new DoNothingBroker().gateHelper(parametersIn0, parametersListOut);
        
        //assemble
        Integer actualCount = (Integer) parametersIn0.get('__Count');
        
        //assert
        Integer expectedCount = null;
        System.assertEquals(expectedCount , actualCount);
    }

 
    
    //TODO :: write test for this when you (NReid) understand this ( cant remember right now)
    // if (count == 0) Database.delete(new List<Id>{(Id)parameters.get('esb__GateGroupId')}); //tidy up split of 0
    
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
        //arrange
        Message__c message = new Message__c(Parameters__c = '{"not_position": 0}');
        insert message;
        
        //act
        Broker broker = new DoNothingBroker();
        
        String actualMessage;
        try {
            List<Message__c> messages = broker.execute(new List<Message__c>{message});
            broker.persist(new List<Message__c>{message}, messages);
        } catch (Broker.EngineException e) {
            actualMessage = e.getMessage();
        }
        //assemble
        Message__c messageActual = (Message__c)SalesforceObject.getById(message.Id);
        
        //assert
        String expectedMessage = 'position, missing';
        System.assert(actualMessage.contains(expectedMessage), actualMessage);
    }
    
    
    
    // TODO - Test Fails
    //        Assume it will be fixed when deailing with Issue "migrate chunking logic into abstract Broker #636"
    // Method Name      testNoStepThrowsQueryException
    // Error Message    System.AssertException: Assertion Failed: Message cannot have a null process.
    // Stack Trace      Class.BrokerTest.testNoStepThrowsQueryException: line 705, column 1
    static testmethod void testNoStepThrowsQueryException() {
        //arrange (note there is no Step__c in database!)
        Message__c message = new Message__c(Parameters__c = '{"__SequenceName": "", "__Position": 0}');
        insert message;
        
        //act
        Broker broker = new DoNothingBroker();
        
        String actualMessage;
        try {
            List<Message__c> messages = broker.execute(new List<Message__c>{message});
            broker.persist(new List<Message__c>{message}, messages);
        } catch (Broker.EngineException e) {
            actualMessage = e.getMessage();
        }
        
        //assemble
        Message__c messageActual = (Message__c)SalesforceObject.getById(message.Id);
        
        //assert
        String expectedMessage = 'Step unqueryable';
        System.assert(actualMessage.contains(expectedMessage), actualMessage);
    }
    
    static testmethod void testProcessWithoutClassThrowsExpectedException() {
        //arrange processes
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange steps
        StepObject.generateOne(sequence.Id, terminateProcess.Id);
        
        terminateProcess.FullyQualifiedClassName__c = 'lalala';
        update terminateProcess; //pretend we deleted the class
        
        //arrange specific broker implementation
        insert new BrokerSetting__c(BrokerClassName__c = SynchronousBroker.class.getName());
        
        //act
        Test.startTest();
        Broker.enqueue(sequence.Name, '000000000000000AAA');
        Test.stopTest();
        
        //assemble
        Message__c message = [SELECT Id, Cause__c, Exception__c FROM Message__c];
        Map<String,Object> actualEx = (Map<String,Object>)Json.deserializeUntyped(message.Cause__c);
        
        //assert
        String actualMessage = message.Exception__c;
        String expectedMessage = 'Reflector for classname was null: lalala';
        System.assertEquals(expectedMessage, (String)actualEx.get('Message'), 'Wrong message detail.');
    }
    
    static testmethod void testNonProcessObjectThrowsTypeException() {
        //arrange processes
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange step
        StepObject.generateOne(sequence.Id, terminateProcess.Id);
        
        terminateProcess.FullyQualifiedClassName__c = 'Account';
        update terminateProcess; //Account is DEFINITELY not a toStringable Object
        
        //arrange specific broker implementation
        insert new BrokerSetting__c(BrokerClassName__c = SynchronousBroker.class.getName());
        
        //act
        Test.startTest();
        Broker.enqueue(sequence.Name, '000000000000000AAA');
        Test.stopTest();
        
        //assemble
        Message__c message = [SELECT Id, Cause__c FROM Message__c];
        Map<String,Object> ex = (Map<String,Object>)Json.deserializeUntyped(message.Cause__c);
        
        //assert
        String actualMessage = (String)ex.get('Message');
        String expectedMessage = 'Could not see ESB inner class, this is not a valid process: Account';
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
            uniqueIds.add(Broker.getEntryPointGuid(len));
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
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);

        String sequenceNameA = 'sequenceA';
        Sequence__c sequenceA = new Sequence__c(Name = sequenceNameA);
        insert sequenceA;


        Integer positionA1 = 1;
        Integer positionA6 = 2;

        Step__c stepA1 = new Step__c(Sequence__c = sequenceA.Id ,Position__c = positionA1,Process__c = wiretapProcess.Id);
        Step__c stepA6 = new Step__c(Sequence__c = sequenceA.Id ,Position__c = positionA6,Process__c = terminateProcess.Id);

        insert stepA1;
        insert stepA6;

        //arrange specific broker implementation
        insert new BrokerSetting__c(BrokerClassName__c = SynchronousBroker.class.getName(), IsPaused__c = isPaused);
        //insert new BrokerSetting__c();

        //act
        Broker.enqueue(sequenceNameA, '000000000000000AAA');


        //assemble
        List<Message__c> messages = [
            SELECT Id, Name, Parameters__c, Status__c
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
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);

        String sequenceNameA = 'sequenceA';
        Sequence__c sequenceA = new Sequence__c(Name = sequenceNameA);
        insert sequenceA;


        Integer positionA1 = 1;
        Integer positionA2 = 2;
        Integer positionA3 = 3;
        Integer positionA4 = 4;
        Integer positionA5 = 5;
        Integer positionA6 = 6;

        Step__c stepA1 = new Step__c(Sequence__c = sequenceA.Id ,Position__c = positionA1,Process__c = wiretapProcess.Id);
        Step__c stepA2 = new Step__c(Sequence__c = sequenceA.Id ,Position__c = positionA2,Process__c = wiretapProcess.Id);
        Step__c stepA3 = new Step__c(Sequence__c = sequenceA.Id ,Position__c = positionA3,Process__c = wiretapProcess.Id);
        Step__c stepA4 = new Step__c(Sequence__c = sequenceA.Id ,Position__c = positionA4,Process__c = wiretapProcess.Id);
        Step__c stepA5 = new Step__c(Sequence__c = sequenceA.Id ,Position__c = positionA5,Process__c = wiretapProcess.Id);
        Step__c stepA6 = new Step__c(Sequence__c = sequenceA.Id ,Position__c = positionA6,Process__c = terminateProcess.Id);

        insert stepA1;
        insert stepA2;
        insert stepA3;
        insert stepA4;
        insert stepA5;
        insert stepA6;
        
        //arrange specific broker implementation
        insert new BrokerSetting__c(BrokerClassName__c = SynchronousBroker.class.getName(), IsPaused__c = isPaused);
        
        //act 
        Broker.enqueue(sequenceNameA, '000000000000000AAA');

        
        //assemble
        List<Message__c> messages = [
            SELECT Id, Name, Parameters__c, Status__c
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
    static testmethod void canFailureToCorrectlyResolveAndPersistMessagesPersistsExpectedError() {
        // arrange
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);

        String sequenceNameA = 'sequenceA';
        Sequence__c sequenceA = new Sequence__c(Name = sequenceNameA);
        insert sequenceA;


        Integer positionA1 = 1;
        Integer positionA2 = 2;
        Integer positionA3 = 3;
        // deleted - implying a resolution issue
        Integer positionA5 = 5;
        Integer positionA6 = 6;

        Step__c stepA1 = new Step__c(Sequence__c = sequenceA.Id ,Position__c = positionA1,Process__c = wiretapProcess.Id);
        Step__c stepA2 = new Step__c(Sequence__c = sequenceA.Id ,Position__c = positionA2,Process__c = wiretapProcess.Id);
        Step__c stepA3 = new Step__c(Sequence__c = sequenceA.Id ,Position__c = positionA3,Process__c = wiretapProcess.Id);
        // deleted - implying a resolution issue
        Step__c stepA5 = new Step__c(Sequence__c = sequenceA.Id ,Position__c = positionA5,Process__c = wiretapProcess.Id);
        Step__c stepA6 = new Step__c(Sequence__c = sequenceA.Id ,Position__c = positionA6,Process__c = terminateProcess.Id);

        insert stepA1;
        insert stepA2;
        insert stepA3;
        // deleted - implying a resolution issue
        insert stepA5;
        insert stepA6;
        
        //arrange specific broker implementation
        insert new BrokerSetting__c(BrokerClassName__c = SynchronousBroker.class.getName(), IsPaused__c = false);
        
        //act 
        Broker.enqueue(sequenceNameA, '000000000000000AAA');

        
        //assemble
        List<Message__c> messagesOk = [
            SELECT Id, Name, Parameters__c, Status__c, Cause__c
            FROM Message__c
            WHERE Status__c = 'Completed'
        ];
        List<Message__c> messagesFailed = [
            SELECT Id, Name, Parameters__c, Status__c, Cause__c
            FROM Message__c
            WHERE Status__c != 'Completed'
        ];
            
        Integer actualCountOk = messagesOk.size();
        Integer actualCountFailed = messagesFailed.size();
        String actualExceptionMessage;
        if (actualCountFailed == 1) {
            actualExceptionMessage = messagesFailed[0].Cause__c;
        }
        
        //assemble
        Map<String,Object> actualException = (Map<String,Object>)Json.deserializeUntyped(actualExceptionMessage);

        // assert
        Integer expectedCountOk = 3;
        System.assertEquals( expectedCountOk, actualCountOk);
        Integer expectedCountFailed = 1;
        System.assertEquals( expectedCountFailed, actualCountFailed);
        String expectedExceptionMessage = 'Step unqueryable, eg bad sequence name, position, missing terminate.';
        System.assertEquals(expectedExceptionMessage, (String)actualException.get('Message'), 'Wrong message');         
    }
 
    static testMethod void callingEnqueueWithParameterCollectionIncludesAllParametersInMessage() {
        // arrange 
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);

        String sequenceName = 'Test';
        Sequence__c sequence = new Sequence__c(Name = sequenceName);
        insert sequence;
        
        Step__c step  = new Step__c(Sequence__c = sequence.Id ,Position__c = 1,Process__c = terminateProcess.Id);
        insert step;
  
        insert new BrokerSetting__c(BrokerClassName__c = SynchronousBroker.class.getName());
        
        String eventStamp = HeartbeatImplementation.getISO8601(DateTime.newInstance(2014,12,15,13,11,07));
        Map<String,Object> parameters = new Map<String,Object>{
            'esb__Id' => UserInfo.getUserId(),
            '__SequenceName' => sequenceName,
            '__EventStamp' => eventStamp
        };
             
        // act
        Broker.enqueue(parameters);

        // assemble
        List<Message__c> actualMessages = [  SELECT  Id, Parameters__c FROM Message__c];
        Integer actualCount  = actualMessages.size();
        String  actualEventStamp;
        if (actualCount == 1) {
            Map<String,Object> actualParameters = (Map<String,Object>)Json.deserializeUntyped(actualMessages[0].Parameters__c);
            actualEventStamp = (String)actualParameters.get('__EventStamp');
        }
 
        // assert
        Integer expectedCount  = 1;
        System.assertEquals(expectedCount, actualCount);
        String  expectedEventStamp = eventStamp;
        System.assertEquals(expectedEventStamp, actualEventStamp);
    }

    static testMethod void callingEnqueueWithoutMandatoryParametersInParametersCollectionThrowsException() {
        // arrange 
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);

        String sequenceName = 'Test';
        Sequence__c sequence = new Sequence__c(Name = sequenceName);
        insert sequence;
        
        Step__c step  = new Step__c(Sequence__c = sequence.Id ,Position__c = 1,Process__c = terminateProcess.Id);
        insert step;
  
        insert new BrokerSetting__c(BrokerClassName__c = SynchronousBroker.class.getName());
        
 
        Map<String,Object> parametersA = new Map<String,Object>{
            '__SequenceName' => sequenceName
        };
        Map<String,Object> parametersB = new Map<String,Object>{
            'esb__Id' => UserInfo.getUserId() 
        };
            
        // assemble
        Boolean actualFlagA = false;
        try {
            // act
            Broker.enqueue(parametersA);
        } catch (Broker.EngineException e) {
            actualFlagA = true;
        }
        
        // assemble
        Boolean actualFlagB = false;
        try {
            // act
            Broker.enqueue(parametersB);
        } catch (Broker.EngineException e) {
            actualFlagB = true;
        }
        
        // assert
        Boolean expectedFlagA = true;
        System.assertEquals(expectedFlagA,actualFlagA);
        Boolean expectedFlagB = true;
        System.assertEquals(expectedFlagB,actualFlagB); 
    } 
    
    
    static testMethod void callingEnqueueAlwaysSetsInitiatingParameters() {
        //arrange processes
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange steps
        StepObject.generateOne(sequence.Id, terminateProcess.Id);
        
        //arrange specific broker implementation
        insert new BrokerSetting__c(BrokerClassName__c = SynchronousBroker.class.getName());
        
        //act
        Test.startTest();
        Broker.enqueue(sequence.Name, '000000000000000AAA');
        Test.stopTest();
        
        // assemble
        List<Message__c> messagesAfter = [SELECT Parameters__c FROM Message__c LIMIT 1];
        
        
        String  actualEntryPointGuid ; 
        Id      actualEnqueueUserId  ; 
        Integer actualPosition       ; 
        if (messagesAfter.size() == 1) {
            Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(messagesAfter[0].Parameters__c);
            actualEntryPointGuid = (String) parameters.get('__EntryPointGuid');
            actualEnqueueUserId  = (Id) parameters.get('__EnqueueUserId' );
            actualPosition       = (Integer) parameters.get('__Position');
        }

        // assert
        String  expectedEntryPointGuid = null;
        System.assertNotEquals(expectedEntryPointGuid,actualEntryPointGuid);
        Id  expectedEnqueueUserId = UserInfo.getUserId();
        System.assertEquals(expectedEnqueueUserId,actualEnqueueUserId);
        Integer expectedPosition = 1;   
        System.assertEquals(expectedPosition ,actualPosition);
    } 

    static testMethod void callingInvokeMainWithCorrectToToStringOverrideDoesNOTThrowException() {
        //arrange
        Map<String,Object> parameters = new Map<String,Object>();
        
        //act
        Boolean actualFlag = true;
        Type reflector = Terminate.class;
        try {
            Broker.Wrapper wrapper = new Broker.Wrapper(reflector, parameters, null).invokeMain();   
        } catch (Exception e) {
            actualFlag = false;   
        }
        
        //assert
        Boolean expectedFlag = true;
        System.assertEquals(expectedFlag, actualFlag, 'Unexpected error thrown by wrapper invokeMain()'); 
    }
    
    static testMethod void callingInvokeMainWhenNoToToStringOverrideThrowsExpectedException() {
        //arrange
        Map<String,Object> parameters = new Map<String,Object>();
        Type reflector = PostInstallHandler.class; // Clearly, no toString() override here!
        
        //act
        Boolean actualFlag = false;
        try {
            Broker.Wrapper wrapper = new Broker.Wrapper(reflector, parameters, null).invokeMain();
        } catch (Broker.EngineException e) {
            actualFlag = e.getMessage().contains('overridden the toString() method');
        } 
        
        //assert
        Boolean expectedFlag = true;
        System.assertEquals(expectedFlag, actualFlag, 'expect exception thrown for [toString() not overridden]');
    }

}