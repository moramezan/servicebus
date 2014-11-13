@IsTest public class BrokerTest { //formerly FailureProcess
    
    @TestVisible static private String FailureMessage = 'Fake Error Thrown in FailureProcess';
    
    @TestVisible private class Meta {
        public String Tag = 'Event Driven Architecture';
        public String Name = 'Failure Process';
        public String Description = 'A toStringable Object that throws an exception for testing purposes.'; //Will not be listed
    }
    
    public String Parameters;
    
    public class DoNothingBroker extends Broker {
        override public void restartImpl() {}
        override public Boolean isAlreadyRunning() {return true;}
    }
    
    override public String toString() {
        Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(this.Parameters);
        throw new BrokerException(FailureMessage);
        return Json.serialize(new List<Map<String,Object>>{parameters});
    }
    
    public class BrokerException extends Exception {}

    static public Boolean flagRestartImpl = false;
    public class MockBroker extends Broker {
        override public Boolean isAlreadyRunning() {
            return false;
        }
        
        override public void restartImpl() {
            flagRestartImpl = true;
        }
    }


    static testmethod void stackDepthExceededWillHaltStartedWithAppropriateMessageDetail() {
        // arrange
        Integer stackDepthThreshold = 3;
        Broker.stackDepthThreshold  = stackDepthThreshold;

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
        insert new BrokerSettings__c(BrokerClassName__c = SynchronousBroker.class.getName());
        
        //act 
        Broker.enqueue(sequenceNameA, '000000000000000AAA');

        
        //assemble
        List<Message__c> messages = [
            SELECT Id, Name, Process__r.Name, Step__c , Parameters__c, Status__c, Exception__c
            FROM Message__c
            WHERE Status__c != 'Completed'
        ];
        
        Integer actualStackDepth;
        String actualDetail;
        String actualStatus;
        Integer actualCount = messages.size();
        if (actualCount > 0) {
            Map<String,Object> actualParameters = (Map<String,Object>)System.Json.deserializeUntyped(messages[0].Parameters__c);
            actualStackDepth = (Integer) actualParameters.get('eda_StackDepth');
            actualDetail = messages[0].Exception__c;
            actualStatus = messages[0].Status__c;
        }
   
        // assert
        Integer expectedCount = 1;
        System.assertEquals( expectedCount, actualCount);
        Integer expectedStackDepth = stackDepthThreshold;
        System.assertEquals( expectedStackDepth, actualStackDepth);
        String expectedDetail = 'Maximum Stack Depth exceeded';
        System.assert(actualDetail.contains(expectedDetail)); 
        String expectedStatus = 'Started';
        System.assertEquals( expectedStatus, actualStatus); 
    }
    
    static testmethod void callingGetStackDepthReturnsExpectedValueWhenStackDepthParameterLtThreshold() {
        //arrange
        Map<String,Object> parameters = new Map<String,Object>();
        Integer threshold = 10;
        Integer stackDepth = 8;
        String key  = 'eda_StackDepth';
        parameters.put(key, stackDepth);
        
        //act
        Integer actualStackDepth = Broker.getStackDepth(parameters, threshold);

        //assert
        Integer expectedStackDepth = stackDepth + 1;
        System.assertEquals( expectedStackDepth, actualStackDepth);
    }



    static testmethod void callingGetStackDepthReturnsExpectedValueWhenStackDepthParameterNotDefined() {
       //arrange
        Map<String,Object> parameters = new Map<String,Object>();
        Integer threshold = 10;
        Integer stackDepth = 0;

        //act
        Integer actualStackDepth = Broker.getStackDepth(parameters, threshold);

        //assert
        Integer expectedStackDepth = stackDepth + 1;
        System.assertEquals( expectedStackDepth, actualStackDepth);
    }
 
  
    static testmethod void callingGetStackDepthThrowsExceptionWhenStackDepthParameterGtOrEqToThreshold() {
       //arrange
        Map<String,Object> parameters = new Map<String,Object>();
        Integer threshold = 10;
        Integer stackDepth = 10;
        String key  = 'eda_StackDepth';
        parameters.put(key, stackDepth);
        
        Boolean actualFlag = false;
        try {
            //act
            Integer actualStackDepth = Broker.getStackDepth(parameters, threshold);
        } catch (Exception e) {
            actualFlag = true;
        }

        //assert
        Boolean expectedFlag = true;
        System.assertEquals( expectedFlag, actualFlag);
    }
    
    
    static testmethod void callingApplyStackDepthCorrectlyAppliesStackDepthToParameters() {
        //arrange
        Integer stackDepth = 8;
        Map<String,Object> parameters = new Map<String,Object>();
        List<Map<String,Object>>  parametersList = new List<Map<String,Object>>{ parameters };

        //act
        parametersList = new DoNothingBroker().applyStackDepth(parametersList, stackDepth);

        //assemble
        Integer actualStackDepth = -1;
        List<Map<String,Object>>  actualParametersList = parametersList;
        for (Map<String,Object> actualParameters : actualParametersList ) {
            actualStackDepth = (Integer) actualParameters.get('eda_StackDepth');
        }
 
        //assert
        Integer expectedStackDepth = stackDepth;
        System.assertEquals( expectedStackDepth, actualStackDepth);
    }
    
 

    static testmethod void canCorrectlyResolveAndPersistMessages() {
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
            new Message__c(Parameters__c = '{"eda_SequenceName": "' + sequenceNameA + '", "eda_Position": ' + positionA1 + '}'),
            new Message__c(Parameters__c = '{"eda_SequenceName": "' + sequenceNameA + '", "eda_Position": ' + positionA2 + '}')
        };
        
        //act
        Broker.impl().resolve(messages);
        insert messages;
        
        // assemble
        List<Message__c> messagesAfter = SalesforceObjectSet.listAll(Message__c.SObjectType);
        
        Boolean flagPosition01 = false;
        Boolean flagPosition02 = false;
        Boolean flagSequenceNameA = true;
        Id actualStepId01;
        Id actualStepId02;
        Id actualProcessId01;
        Id actualProcessId02;
        for (Message__c message : messagesAfter) {
            Map<String,Object> parameters = (Map<String,Object>)System.Json.deserializeUntyped(message.Parameters__c);
            String parametersSequenceName = (String)parameters.get('eda_SequenceName');
            Integer parametersPosition = (Integer)parameters.get('eda_Position');
            if (parametersSequenceName != sequenceNameA) {
                flagSequenceNameA = false;
            }
            if (parametersPosition == (positionA1 + 1))  {
                flagPosition01 = true;
                actualStepId01 = message.Step__c;
                actualProcessId01 = message.Process__c;
            }
            if (parametersPosition == (positionA2 + 1))  {
                flagPosition02 = true;
                actualStepId02 = message.Step__c;
                actualProcessId02 = message.Process__c;
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
        System.assertEquals(expectedStepId01, actualStepId01);
        System.assertEquals(expectedStepId02, actualStepId02);
        System.assertEquals(expectedProcessId01, actualProcessId01  );
        System.assertEquals(expectedProcessId02, actualProcessId02  );
    }
    
    static testmethod void testLocatorMarksCorrectNumberOfMessages() {
        //arrange
        Integer queryLimit = 2;
        
        insert new List<Message__c>{
            new Message__c(Status__c = 'Buffered'),
            new Message__c(Status__c = 'Buffered'),
            new Message__c(Status__c = 'Buffered')
        };
        
        //act
        MockBroker broker = new MockBroker();
        Database.QueryLocator locator = broker.locateMarkableWork(queryLimit);
        Database.QueryLocatorIterator iterator = locator.iterator();
        
        //MARK
        broker.mark(new ApexPages.StandardSetController(locator).getRecords());
        
        List<Message__c> messages = new List<Message__c>();
        while (iterator.hasNext()) messages.add((Message__c)iterator.next());
        
        //assert
        Integer actualCount = messages.size();
        Integer expectedCount = 2;
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testmethod void testLocatorOnlyMarksNonStartedWork() {
        //arrange
        Integer fuckedLimit = 2;
        
        insert new List<Message__c>{
            new Message__c(Status__c = 'Started'),
            new Message__c(Status__c = 'Started')
        };
    
        //act
        Database.QueryLocatorIterator iterator = new MockBroker().locateMarkableWork(fuckedLimit).iterator();
        List<Message__c> messages = new List<Message__c>();
        while (iterator.hasNext()) messages.add((Message__c)iterator.next());
        
        //assert
        Integer expectedCount = 0;
        Integer actualCount = messages.size();
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testmethod void testLocatorReturnsOnlyRebufferedWork() {
        Integer workCount = 2;
        
        //arrange fucked messages
        insert new List<Message__c>{
            new Message__c(Status__c = 'Started'),
            new Message__c(Status__c = 'Started')
        };
        
        //arrange Rebuffered messages
        insert new List<Message__c>{
            new Message__c(Status__c = 'Rebuffered'),
            new Message__c(Status__c = 'Rebuffered')
        };
        
        //act
        MockBroker broker = new MockBroker();
        Database.QueryLocator locator = broker.locateMarkableWork(workCount);
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
    
    static testmethod void callingSurfaceExceptionSurfacesExpectedMessageOnMessage() {
        //arrange
        Message__c message = new Message__c(
            Parameters__c = '{"Id":1, "eda_SequenceName":"crow", "eda_Position":1}'
        );
        insert message;
        
        String theMessage = 'balls';
        BrokerException e = new BrokerException(theMessage);
        
        //act
        Id messageId = message.Id;
        new DoNothingBroker().surfaceException(e, messageId) ;
        
        //assemble
        List<Message__c> messages = [
            SELECT Id, Name, Parameters__c, Exception__c
            FROM Message__c
        ];
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = messages.size();
        System.assertEquals(expectedSize, actualSize);
        
        
        String expectedMessage = theMessage;
        String actualMessage = messages[0].Exception__c;
        System.assert(actualMessage.contains(expectedMessage));
    }
    
    static testmethod void canCorrectlyResolveMessages() {
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
            new Message__c(Parameters__c = '{"Id": 0, "eda_SequenceName": "' + sequenceA.Name + '", "eda_Position": ' + positionA1 + '}'), // Same Sequence / Position
            new Message__c(Parameters__c = '{"Id": 1, "eda_SequenceName": "' + sequenceA.Name + '", "eda_Position": ' + positionA1 + '}'), // Same Sequence / Position
            new Message__c(Parameters__c = '{"Id": 2, "eda_SequenceName": "' + sequenceA.Name + '", "eda_Position": ' + positionA2 + '}'),
            new Message__c(Parameters__c = '{"Id": 3, "eda_SequenceName": "' + sequenceB.Name + '", "eda_Position": ' + positionB1 + '}'),
            new Message__c(Parameters__c = '{"Id": 4, "eda_SequenceName": "' + sequenceC.Name + '", "eda_Position": ' + positionC1 + '}')
        };
        
        // act
        Broker.impl().resolve(messages);
        
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
            Integer theId = (Integer) parameters.get('Id');
            String theSequenceName = (String)parameters.get('eda_SequenceName');
            Integer thePosition = (Integer)parameters.get('eda_Position');
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
        insert new BrokerSettings__c(BrokerClassName__c = BrokerTest.MockBroker.class.getName());
        
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
        insert new BrokerSettings__c(BrokerClassName__c = BrokerTest.MockBroker.class.getName());
        
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
        insert new BrokerSettings__c(BrokerClassName__c = BrokerTest.MockBroker.class.getName());
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
    
    static testmethod void callingGateHelperCorrectlySetsCountOnParametersWhenMarkCountIncrementsTo2() {
        //arrange
        Integer markCount = 1;
        Map<String,Object> parametersIn0 = new Map<String,Object> {
            'Id' => '0',
            'eda_MarkCount' => markCount
        };
        
        Map<String,Object> parametersOut1 = new Map<String,Object> {
            'Id' => '1'
        };
        
        Map<String,Object> parametersOut2 = new Map<String,Object> {
            'Id' => '2'
        };
        
        Map<String,Object> parametersOut3 = new Map<String,Object> {
            'Id' => '3'
        };
        
        List<Map<String,Object>> parametersListOut = new List<Map<String,Object>> { parametersOut1, parametersOut2, parametersOut3 };
        
        //act
        new DoNothingBroker().gateHelper(parametersIn0, parametersListOut);
        
        //assemble
        Integer actualCount = (Integer)parametersListOut[0].get('eda_Count');
        
        //assert
        Integer expectedCount = parametersListOut.size();
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testmethod void callingGateHelperDoesNotSetCountOnParametersWhenMarkCountIncrementsToOtherThan2() {
        //arrange
        Integer markCount = 0; //will not increment to 2
        Map<String,Object> parametersIn0 = new Map<String,Object> {
            'Id' => '0',
            'eda_MarkCount' => markCount
        };
        
        List<Map<String,Object>> parametersListOut = new List<Map<String,Object>>();
        
        //act
        new DoNothingBroker().gateHelper(parametersIn0, parametersListOut);
        
        //assemble
        Integer actualCount = (Integer)parametersIn0.get('eda_Count');
        
        //assert
        Integer expectedCount = null;
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testmethod void callingGateHelperDoesNotSetCountOnParametersWhenMarkCountIsNull() {
        //arrange
        Map<String,Object> parametersIn0 = new Map<String,Object> {
            'Id' => '0'
            //'eda_MarkCount' => markCount //Not specified; key will return null
        };
        
        List<Map<String,Object>> parametersListOut = new List<Map<String,Object>>();
        
        //act
        new DoNothingBroker().gateHelper(parametersIn0, parametersListOut);
        
        //assemble
        Integer actualCount = (Integer) parametersIn0.get('eda_Count');
        
        //assert
        Integer expectedCount = null;
        System.assertEquals(expectedCount , actualCount);
    }

 
    
    //TODO :: write test for this when you (NReid) understand this ( cant remember right now)
    // if (count == 0) Database.delete(new List<Id>{(Id)parameters.get('eda_GateGroupId')}); //tidy up split of 0
    
    /**
     * Bug with Salesforce:
     * We cannot legitimately test for recycle bin purges - See Andy Fawcett's stackexchange comment:
     * http://salesforce.stackexchange.com/questions/27180/database-emptyrecyclebin-exhibits-unexpected-behaviour
     */
    
    static testmethod void testMalformedParametersThrowsSystemJsonException() {
        //arrange
        Message__c message = new Message__c(Parameters__c = '{"malformed":....}');
        insert message;
        
        //act
        Broker broker = new DoNothingBroker();
        String actualMessage;
        try {
            List<Message__c> messages = broker.execute(new List<Message__c>{message});
            broker.resolve(messages);
            broker.persist(new List<Message__c>{message}, messages);
        } catch (Exception e) {
            actualMessage = e.getMessage();
        }
        
        //assemble
        Message__c messageActual = (Message__c)SalesforceObject.getById(message.Id);
        
        //assert
        String expectedMessage = 'Could not deserialize json';
        System.assert(actualMessage.contains(expectedMessage), actualMessage);
    }
    
    static testmethod void testMissingPositionThrowsExpectedException() {
        //arrange
        Message__c message = new Message__c(Parameters__c = '{"not_position": 0}');
        insert message;
        
        //act
        Broker broker = new DoNothingBroker();
        
        String actualMessage;
        try {
            List<Message__c> messages = broker.execute(new List<Message__c>{message});
            broker.resolve(messages);
            broker.persist(new List<Message__c>{message}, messages);
        } catch (Exception e) {
            actualMessage = e.getMessage();
        }
        //assemble
        Message__c messageActual = (Message__c)SalesforceObject.getById(message.Id);
        
        //assert
        String expectedMessage = 'position, missing';
        System.assert(actualMessage.contains(expectedMessage), actualMessage);
    }
    
    static testmethod void testNoStepThrowsQueryException() {
        //arrange (note there is no Step__c in database!)
        Message__c message = new Message__c(Parameters__c = '{"eda_SequenceName": "", "eda_Position": 0}');
        insert message;
        
        //act
        Broker broker = new DoNothingBroker();
        
        String actualMessage;
        try {
            List<Message__c> messages = broker.execute(new List<Message__c>{message});
            broker.resolve(messages);
            broker.persist(new List<Message__c>{message}, messages);
        } catch (Exception e) {
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
        insert new BrokerSettings__c(BrokerClassName__c = SynchronousBroker.class.getName());
        
        //act
        Test.startTest();
        Broker.enqueue(sequence.Name, '000000000000000AAA');
        Test.stopTest();
        
        //assemble
        Message__c message = [SELECT Id, Exception__c FROM Message__c];
        
        //assert
        String actualMessage = message.Exception__c;
        String expectedMessage = 'class missing';
        System.assert(actualMessage.contains(expectedMessage), actualMessage);
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
        insert new BrokerSettings__c(BrokerClassName__c = SynchronousBroker.class.getName());
        
        //act
        Test.startTest();
        Broker.enqueue(sequence.Name, '000000000000000AAA');
        Test.stopTest();
        
        //assert
        Message__c message = [SELECT Id, Exception__c FROM Message__c];
        String actualMessage = message.Exception__c;
        String expectedMessage = 'No such column \'Parameters\' on sobject of type Account';
        System.assert(actualMessage.contains(expectedMessage), actualMessage);
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
        insert new BrokerSettings__c(BrokerClassName__c = SynchronousBroker.class.getName(), IsPaused__c = isPaused);
        //insert new BrokerSettings__c();

        //act
        Broker.enqueue(sequenceNameA, '000000000000000AAA');


        //assemble
        List<Message__c> messages = [
            SELECT Id, Name, Process__r.Name, Step__c , Parameters__c, Status__c, Exception__c
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
        insert new BrokerSettings__c(BrokerClassName__c = SynchronousBroker.class.getName(), IsPaused__c = isPaused);
        
        //act 
        Broker.enqueue(sequenceNameA, '000000000000000AAA');

        
        //assemble
        List<Message__c> messages = [
            SELECT Id, Name, Process__r.Name, Step__c , Parameters__c, Status__c, Exception__c
            FROM Message__c
            WHERE Status__c = 'Completed'
        ];

        Integer actualCount = messages.size();

   
        // assert
        Integer expectedCount = 6;
        System.assertEquals( expectedCount, actualCount);
    }
 
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
        insert new BrokerSettings__c(BrokerClassName__c = SynchronousBroker.class.getName(), IsPaused__c = false);
        
        //act 
        Broker.enqueue(sequenceNameA, '000000000000000AAA');

        
        //assemble
        List<Message__c> messagesOk = [
            SELECT Id, Name, Process__r.Name, Step__c , Parameters__c, Status__c, Exception__c
            FROM Message__c
            WHERE Status__c = 'Completed'
        ];
        List<Message__c> messagesFailed = [
            SELECT Id, Name, Process__r.Name, Step__c , Parameters__c, Status__c, Exception__c
            FROM Message__c
            WHERE Status__c != 'Completed'
        ];
            
        Integer actualCountOk = messagesOk.size();
        Integer actualCountFailed = messagesFailed.size();
        String actualExceptionMessage;
        if (actualCountFailed == 1) {
            actualExceptionMessage = messagesFailed[0].Exception__c;
        }

        // assert
        Integer expectedCountOk = 2;
        System.assertEquals( expectedCountOk, actualCountOk);
        Integer expectedCountFailed = 1;
        System.assertEquals( expectedCountFailed, actualCountFailed);
        String expectedExceptionMessage = 'Resolve failure';
        System.assert(actualExceptionMessage.contains(expectedExceptionMessage));         
    }
 
    static testMethod void callingEnqueueWithParameterCollectionIncludesAllParametersInMessage() {
        // arrange 
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);

        String sequenceName = 'Test';
        Sequence__c sequence = new Sequence__c(Name = sequenceName);
        insert sequence;
        
        Step__c step  = new Step__c(Sequence__c = sequence.Id ,Position__c = 1,Process__c = terminateProcess.Id);
        insert step;
  
        insert new BrokerSettings__c(BrokerClassName__c = SynchronousBroker.class.getName());
        
        String eventStamp = HeartbeatImplementation.getISO8601(DateTime.newInstance(2014,12,15,13,11,07));
        Boolean isHeartbeat = true;
        Map<String,Object> parameters = new Map<String,Object>{
            'Id' => UserInfo.getUserId(), 
            'eda_SequenceName' => sequenceName,    
            'eda_EventStamp' => eventStamp,
            'eda_IsHeartbeat' => isHeartbeat    
        };
             
        // act
        Broker.enqueue(parameters);

        // assemble
        List<Message__c> actualMessages = [  SELECT  Id, Parameters__c FROM Message__c];
        Integer actualCount  = actualMessages.size();
        String  actualEventStamp;
        Boolean actualIsHeartbeat;
        if (actualCount == 1) {
            Map<String,Object> actualParameters = (Map<String,Object>)Json.deserializeUntyped(actualMessages[0].Parameters__c);
            actualEventStamp = (String)actualParameters.get('eda_EventStamp');
            actualIsHeartbeat = (Boolean)actualParameters.get('eda_IsHeartbeat');
        }
 
        // assert
        Integer expectedCount  = 1;
        System.assertEquals(expectedCount, actualCount);
        String  expectedEventStamp = eventStamp;
        System.assertEquals(expectedEventStamp, actualEventStamp);
        Boolean expectedIsHeartbeat = isHeartbeat; 
        System.assertEquals(expectedIsHeartbeat,actualIsHeartbeat);
    }

    static testMethod void callingEnqueueWithoutMandatoryParametersInParametersCollectionThrowsException() {
        // arrange 
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);

        String sequenceName = 'Test';
        Sequence__c sequence = new Sequence__c(Name = sequenceName);
        insert sequence;
        
        Step__c step  = new Step__c(Sequence__c = sequence.Id ,Position__c = 1,Process__c = terminateProcess.Id);
        insert step;
  
        insert new BrokerSettings__c(BrokerClassName__c = SynchronousBroker.class.getName());
        
 
        Map<String,Object> parametersA = new Map<String,Object>{
            'eda_SequenceName' => sequenceName
        };
        Map<String,Object> parametersB = new Map<String,Object>{
            'Id' => UserInfo.getUserId() 
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
}