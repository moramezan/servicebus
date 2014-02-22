@isTest
public class BrokerTest{

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
    
    static testMethod void canCorrectlyResolveAndPersistMessages() {
        //arrange processes
        Process__c markProcess = Processes.generateOne(Mark.class);
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        Process__c subscribeProcess = Processes.generateOne(Subscribe.class);
        
        //arrange chain
        String chainNameA = 'chainA';
        Chain__c chainA = new Chain__c(Name = chainNameA);
        insert chainA;
        
        //arrange steps
        ChainStep__c stepA1 = ChainSteps.generateOne(chainA.Id, subscribeProcess.Id);
        ChainStep__c stepA2 = ChainSteps.generateOne(chainA.Id, markProcess.Id);
        ChainStep__c stepA3 = ChainSteps.generateOne(chainA.Id, terminateProcess.Id);
        Decimal sequenceA1 = stepA1.Sequence__c;
        Decimal sequenceA2 = stepA2.Sequence__c;
        Decimal sequenceA3 = stepA3.Sequence__c;
        
        List<Message__c> messages =  new List<Message__c>{
            new Message__c(Parameters__c = '{"eda__chainName": "' + chainNameA + '", "eda__sequence": ' + sequenceA1 + '}'),
            new Message__c(Parameters__c = '{"eda__chainName": "' + chainNameA + '", "eda__sequence": ' + sequenceA2 + '}')
        };
        
        //act
        Broker.resolve(messages);
        insert messages; //persist
        
        // assemble
        List<Message__c> messagesAfter = [
            SELECT id, Parameters__c, ChainStep__c, Process__c 
            FROM Message__c
        ];
        
        Boolean flagSequence01 = false;
        Boolean flagSequence02 = false;
        Boolean flagChainNameA = true;
        Id actualChainStepId01;
        Id actualChainStepId02;    
        Id actualProcessId01;
        Id actualProcessId02;
        for (Message__c message : messagesAfter) {
            Map<String,Object> parameters = (Map<String,Object>)System.Json.deserializeUntyped(message.Parameters__c);
            String parametersChainName = (String)parameters.get('eda__chainName');
            Integer parametersSequence = (Integer)parameters.get('eda__sequence');
            if (parametersChainName != chainNameA) {
                flagChainNameA = false;
            }
            if (parametersSequence == (sequenceA1 + 1))  {
                flagSequence01 = true;
                actualChainStepId01 = message.ChainStep__c;
                actualProcessId01 = message.Process__c;
            }
            if (parametersSequence == (sequenceA2 + 1))  {
                flagSequence02 = true;
                actualChainStepId02 = message.ChainStep__c;
                actualProcessId02 = message.Process__c;
            }
        }
        
        // assert
        Integer expectedCount = 2;
        Integer actualCount = messagesAfter.size();
        System.assertEquals(expectedCount, actualCount);

        System.assert(flagChainNameA);
        System.assert(flagSequence01);
        System.assert(flagSequence02);

        Id expectedChainStepId01 = stepA2.Id;
        Id expectedChainStepId02 = stepA3.Id ;
        Id expectedProcessId01 = markProcess.Id;
        Id expectedProcessId02 = terminateProcess.Id;    
        System.assertEquals(expectedChainStepId01, actualChainStepId01);
        System.assertEquals(expectedChainStepId02, actualChainStepId02); 
        System.assertEquals(expectedProcessId01, actualProcessId01  );
        System.assertEquals(expectedProcessId02, actualProcessId02  );
    }
    
    static testMethod void testLocatorMarksCorrectNumberOfMessages() {
        //arrange
        Integer queryLimit = 2;
        
        insert new List<Message__c>{
            new Message__c(Status__c = 'Buffer'),
            new Message__c(Status__c = 'Buffer'),
            new Message__c(Status__c = 'Buffer')  
        };
        
        //act  
        MockBroker broker = new MockBroker();
        Database.QueryLocatorIterator iterator = broker.locateMarkedWork(queryLimit).iterator();
        List<Message__c> messages = new List<Message__c>();
        while (iterator.hasNext()) messages.add((Message__c)iterator.next());
        
        //assert
        Integer actualCount = messages.size();
        Integer expectedCount = 2;
        System.assertEquals(expectedCount, actualCount); 
    }
    
    static testMethod void testLocatorOnlyMarksNonProcessingWork() {
        //arrange
        Integer fuckedLimit = 2;
        
        insert new List<Message__c>{
            new Message__c(Status__c = 'Processing'),
            new Message__c(Status__c = 'Processing')
        };
    
        //act                                                                                                                                                                    
        Database.QueryLocatorIterator iterator = new MockBroker().locateMarkedWork(fuckedLimit).iterator();
        List<Message__c> messages = new List<Message__c>();
        while (iterator.hasNext()) messages.add((Message__c)iterator.next());
        
        //assert
        Integer expectedCount = 0;
        Integer actualCount = messages.size();
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testMethod void testLocatorReturnsOnlyReprocessWork() {
        Integer workCount = 2;
        
        //arrange fucked messages
        insert new List<Message__c>{
            new Message__c(Status__c = 'Processing'),
            new Message__c(Status__c = 'Processing') 
        };
        
        //arrange reprocess messages
        insert new List<Message__c>{
            new Message__c(Status__c = 'Reprocess'),
            new Message__c(Status__c = 'Reprocess') 
        };
        
        //act
        MockBroker broker = new MockBroker();
        Database.QueryLocatorIterator iterator = broker.locateMarkedWork(workCount).iterator();
        List<Message__c> messages = new List<Message__c>();
        while (iterator.hasNext()) messages.add((Message__c)iterator.next());
        
        // assert
        Integer expectedCount = 2;
        Integer actualCount = messages.size();
        System.assertEquals(expectedCount, actualCount); 
    }
    
    static testMethod void callingSurfaceExceptionSurfacesExpectedMessageOnMessage() {
        //arrange
        Message__c message = new Message__c(
            Parameters__c = '{"id":1, "eda__chainName":"crow", "eda__sequence":1}'
        );
        insert message;
        
        String theMessage = 'balls';
        BrokerException e = new BrokerException(theMessage);
        
        //act
        Id messageId = message.Id;
        Broker.surfaceException(e, messageId) ;
        
        //assemble
        List<Message__c> messages = [
            SELECT Id, Name, Parameters__c, Message__c 
            FROM Message__c
        ];
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = messages.size();
        System.assertEquals(expectedSize, actualSize);
        
        
        String expectedMessage = theMessage;
        String actualMessage = messages[0].Message__c; 
        System.assert(actualMessage.contains(expectedMessage));
    } 
    
    static testMethod void canCorrectlyResolveMessages() {
        // arrange
        Process__c markProcess = Processes.generateOne(Mark.class);
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        Process__c wiretapProcess = Processes.generateOne(Wiretap.class);
        Process__c subscribeProcess = Processes.generateOne(Subscribe.class);

        String chainNameA = 'chainA';
        String chainNameB = 'chainB';
        String chainNameC = 'chainC';
        Chain__c chainA = new Chain__c(Name = chainNameA);
        Chain__c chainB = new Chain__c(Name = chainNameB);
        Chain__c chainC = new Chain__c(Name = chainNAmeC);
        insert chainA;
        insert chainB;
        insert chainC;

        Integer sequenceA1 = 1;
        Integer sequenceA2 = 2;
        Integer sequenceA3 = 3;
        Integer sequenceB1 = 1;
        Integer sequenceB2 = 2;
        Integer sequenceC1 = 1;
        Integer sequenceC2 = 2;
        ChainStep__c stepA1 = new ChainStep__c(Chain__c = chainA.Id ,Sequence__c = sequenceA1,Process__c = subscribeProcess.Id);
        ChainStep__c stepA2 = new ChainStep__c(Chain__c = chainA.Id ,Sequence__c = sequenceA2,Process__c = markProcess.Id);
        ChainStep__c stepA3 = new ChainStep__c(Chain__c = chainA.Id ,Sequence__c = sequenceA3,Process__c = terminateProcess.Id);
        ChainStep__c stepB1 = new ChainStep__c(Chain__c = chainB.Id ,Sequence__c = sequenceB1,Process__c = wiretapProcess.Id);
        ChainStep__c stepB2 = new ChainStep__c(Chain__c = chainB.Id ,Sequence__c = sequenceB2,Process__c = terminateProcess.Id); 
        ChainStep__c stepC1 = new ChainStep__c(Chain__c = chainC.Id ,Sequence__c = sequenceC1,Process__c = markProcess.Id);
        ChainStep__c stepC2 = new ChainStep__c(Chain__c = chainC.Id ,Sequence__c = sequenceC2,Process__c = terminateProcess.Id); 
        insert stepA1;
        insert stepA2;
        insert stepA3;
        insert stepB1;
        insert stepB2;
        insert stepC1;
        insert stepC2;
        
        List<Message__c> messages = new List<Message__c>{
            new Message__c(Parameters__c = '{"id": 1, "eda__chainName": "' + chainA.Name + '", "eda__sequence": ' + sequenceA1 + '}'),
            new Message__c(Parameters__c = '{"id": 2, "eda__chainName": "' + chainA.Name + '", "eda__sequence": ' + sequenceA2 + '}'),
            new Message__c(Parameters__c = '{"id": 3, "eda__chainName": "' + chainB.Name + '", "eda__sequence": ' + sequenceB1 + '}'),
            new Message__c(Parameters__c = '{"id": 4, "eda__chainName": "' + chainC.Name + '", "eda__sequence": ' + sequenceC1 + '}')
        };
        
        // act
        Broker.resolve(messages);
        
        // assemble
        String actualChainName1 = '' ;
        String actualChainName2 = '' ;
        String actualChainName3 = '' ;
        String actualChainName4 = '' ;
        Integer actualSequence1 = -1 ;
        Integer actualSequence2 = -1 ;
        Integer actualSequence3 = -1 ;
        Integer actualSequence4 = -1 ;
        for (Message__c message : messages) {
            Map<String,Object> parameters = (Map<String,Object>)System.Json.deserializeUntyped(message.Parameters__c);
            Integer theId = (Integer) parameters.get('id');
            String theChainName = (String)parameters.get('eda__chainName');
            Integer theSequence = (Integer)parameters.get('eda__sequence'); 
            if (theId == 1) {
                actualChainName1 = theChainName;
                actualSequence1 = theSequence;
            }
            if (theId == 2) {
                actualChainName2 = theChainName;
                actualSequence2 = theSequence;
            
            }
            if (theId == 3) {
                actualChainName3 = theChainName;
                actualSequence3 = theSequence;
            }
            if (theId == 4) {
                actualChainName4 = theChainName;
                actualSequence4 = theSequence;
            } 
        }
        
        // assert
        Integer expectedCount = 4;
        Integer actualCount = messages.size();
        System.assertEquals(expectedCount, actualCount);
        
        String expectedChainName1 = chainNameA;
        String expectedChainName2 = chainNameA;
        String expectedChainName3 = chainNameB;
        String expectedChainName4 = chainNameC;
        Integer expectedSequence1 = sequenceA1 + 1;
        Integer expectedSequence2 = sequenceA2 + 1;
        Integer expectedSequence3 = sequenceB1 + 1;
        Integer expectedSequence4 = sequenceC1 + 1;
        System.assertEquals(expectedSequence1, actualSequence1);
        System.assertEquals(expectedSequence2, actualSequence2);
        System.assertEquals(expectedSequence3, actualSequence3);
        System.assertEquals(expectedSequence4, actualSequence4); 
        System.assertEquals(expectedChainName1, actualChainName1);
        System.assertEquals(expectedChainName2, actualChainName2);
        System.assertEquals(expectedChainName3, actualChainName3);
        System.assertEquals(expectedChainName4, actualChainName4); 
    } 
    
    static testMethod void callingEnqueueSuccessfullyCallsRestartImpl() {
        //arrange processes
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        
        //arrange chain
        Chain__c chain = new Chain__c(Name = 'TestChain');
        insert chain;
        
        //arrange steps
        ChainSteps.generateOne(chain.Id, terminateProcess.Id);
        
        //arrange broker implementation custom setting
        String theChainName = 'TestChain';
        Id theId = '000000000000000AAA'; 
        insert new BrokerSettings__c(BrokerClassName__c = BrokerTest.MockBroker.class.getName());
        
        //assert
        Boolean expectedBeforeFlag = false;
        Boolean actualBeforeFlag = BrokerTest.flagRestartImpl;
        System.assertEquals(expectedBeforeFlag, actualBeforeFlag); 
        
        //act
        Broker.enqueue(theChainName, theId); 
        
        //assert
        Boolean expectedAfterFlag = true;
        Boolean actualAfterFlag = flagRestartImpl;
        System.assertEquals(expectedAfterFlag, actualAfterFlag); 
    }
    
    static testMethod void callingEnqueueSuccessfullyCallEnqueueImpAndCreatesDocument() {
        //arrange processes
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        
        //arrange chain
        Chain__c chain = new Chain__c(Name = 'TestChain');
        insert chain;
        
        //arrange steps
        ChainSteps.generateOne(chain.Id, terminateProcess.Id);
        
        //arrange
        insert new BrokerSettings__c(BrokerClassName__c = BrokerTest.MockBroker.class.getName());
        
        //assert
        Boolean expectedBeforeFlag = false;
        Boolean actualBeforeFlag = BrokerTest.flagRestartImpl;
        System.assertEquals(expectedBeforeFlag, actualBeforeFlag);
        
        Integer expectedSizeBefore = 0;
        Integer actualSizeBefore = [SELECT Id FROM Document].size();
        System.assertEquals(expectedSizeBefore , actualSizeBefore); 
        
        //act  
        Broker.enqueue('TestChain', Blob.valueOf('balls')); 
        
        //assert
        Integer expectedSizeAfter = 1;
        Integer actualSizeAfter = [SELECT id FROM Document].size();
        System.assertEquals(expectedSizeAfter, actualSizeAfter);
        
        Boolean expectedAfterFlag = true;
        Boolean actualAfterFlag = BrokerTest.flagRestartImpl;
        System.assertEquals(expectedAfterFlag, actualAfterFlag);
    } 
    
    static testMethod void callingRestartSuccessfullyCallsRestartImpl() {
        //arrange
        insert new BrokerSettings__c(BrokerClassName__c = BrokerTest.MockBroker.class.getName());
        insert new Message__c(Status__c = 'Reprocess');
        
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
    
    static testMethod void callingMarkHelperCorrectlySetsCountOnParametersWhenMarkCountIncrementsTo2() {
        //arrange 
        Integer markCount = 1;
        Map<String,Object> parametersIn0 = new Map<String,Object> { 
            'id' => '0',
            'eda__markCount' => markCount
        }; 
        
        Map<String,Object> parametersOut1 = new Map<String,Object> { 
            'id' => '1'
        }; 
        
        Map<String,Object> parametersOut2 = new Map<String,Object> { 
            'id' => '2'
        }; 
        
        Map<String,Object> parametersOut3 = new Map<String,Object> { 
            'id' => '3'
        };
        
        List<Map<String,Object>> parametersListOut = new List<Map<String,Object>> { parametersOut1, parametersOut2, parametersOut3 };
        
        //act  
        Broker.markHelper(parametersIn0, parametersListOut);
        
        //assemble 
        Integer actualCount = (Integer)parametersIn0.get('eda__count');
        
        //assert
        Integer expectedCount = parametersListOut.size();
        System.assertEquals(expectedCount, actualCount); 
    } 
    
    static testMethod void callingMarkHelperDoesNotSetCountOnParametersWhenMarkCountIncrementsToOtherThan2() {
        //arrange 
        Integer markCount = 0; //will not increment to 2
        Map<String,Object> parametersIn0 = new Map<String,Object> { 
            'id' => '0',
            'eda__markCount' => markCount
        }; 
        
        List<Map<String,Object>> parametersListOut = new List<Map<String,Object>>();
        
        //act  
        Broker.markHelper(parametersIn0, parametersListOut);
        
        //assemble 
        Integer actualCount = (Integer)parametersIn0.get('eda__count');
        
        //assert
        Integer expectedCount = null;
        System.assertEquals(expectedCount, actualCount); 
    } 
    
    static testMethod void callingMarkHelperDoesNotSetCountOnParametersWhenMarkCountIsNull() {
        //arrange 
        Map<String,Object> parametersIn0 = new Map<String,Object> { 
            'id' => '0' 
            //'eda__markCount' => markCount //Not specified; key will return null
        }; 
        
        List<Map<String,Object>> parametersListOut = new List<Map<String,Object>>();
        
        //act  
        Broker.markHelper(parametersIn0, parametersListOut);
        
        //assemble 
        Integer actualCount = (Integer) parametersIn0.get('eda__count');
        
        //assert
        Integer expectedCount = null;
        System.assertEquals(expectedCount , actualCount); 
    }
    
    //TODO :: write test for this when you (NReid) understand this ( cant remember right now)
    // if (count == 0) Database.delete(new List<Id>{(Id)parameters.get('eda__gateGroupId')}); //tidy up split of 0
    
    /**
     * Bug with Salesforce:
     * We cannot legitimately test for recycle bin purges - See Andy Fawcett's stackexchange comment:
     * http://salesforce.stackexchange.com/questions/27180/database-emptyrecyclebin-exhibits-unexpected-behaviour
     */
    
    /**
     * TODO : this test will fail until we resolve issue #178
     * Since the different engines fundamentally persist at different points
     * it will be difficult to do the try catch in the base class - each 
     * broker implementation should  implement the try catch around the resolve 
     *  and if exception then 1. no deletion of input message
     * 2. no persistence of returned messages collection 3. save 
     * error against input message
     */
    /*static testmethod void testDodgyProcess() {
        // arrange
        Process__c markProcess = Processes.generateOne(Mark.class);
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        
        // arrange chain
        String chainNameA = 'chainA';
        Chain__c chainA = new Chain__c(Name = chainNameA);
        insert chainA;
        
        
        // arrange steps
        Integer sequenceA1 = 1;
        Integer sequenceA2 = 2;
        ChainStep__c stepA1 = new ChainStep__c(Chain__c = chainA.Id ,Sequence__c = sequenceA1,Process__c = markProcess.Id);
        ChainStep__c stepA2 = new ChainStep__c(Chain__c = chainA.Id ,Sequence__c = sequenceA2,Process__c = terminateProcess.Id);
        insert stepA1;
        insert stepA2;
        
        //simulate dodgy process by deleting reference
        markProcess.FullyQualifiedClassName__c = null;
        update markProcess;
        
        insert new BrokerSettings__c(BrokerClassName__c = BatchBroker.class.getName() );
        
        // act
        Test.startTest();
        Broker.enqueue('testChain', '000000000000000AAA');
        Test.stopTest();
        
        // arrange
        Message__c message = [SELECT Id, Message__c FROM Message__c];
        
        // asserts
        String expectedMessage = 'class missing';
        String actualMessage = message.Message__c;
        System.assert(actualMessage.contains(expectedMessage));
    }
    */
        
    static testMethod void testMalformedParametersThrowsSystemJsonException() {
        //arrange
        Message__c message = new Message__c(Parameters__c = '{"malformed":....}');
        insert message;
        
        //act
        Broker.executeResolvePersist(message.Id);
        
        //assemble 
        Message__c messageActual = [SELECT id, Message__c FROM Message__c WHERE id = :message.Id];
        
        //assert
        String actualMessage = messageActual.Message__c;
        String expectedMessage = 'Could not deserialize json';
        System.assert(actualMessage.contains(expectedMessage), actualMessage);
    }
    
    static testMethod void testMissingSequenceThrowsExpectedException() {
        //arrange
        Message__c message = new Message__c(Parameters__c = '{"not_sequence": 0}');
        insert message;
        
        //act
        Broker.executeResolvePersist(message.Id);
        
        //assemble 
        Message__c messageActual = [SELECT id, Message__c FROM Message__c WHERE id = :message.Id];
        
        //assert
        String actualMessage = messageActual.Message__c;
        String expectedMessage = 'sequence';
        System.assert(actualMessage.contains(expectedMessage), actualMessage);
    }
    
    static testMethod void testNoChainStepThrowsQueryException() {
        //arrange (note there is no ChainStep__c in database!)
        Message__c message = new Message__c(Parameters__c = '{"eda__chainName": "", "eda__sequence": 0}');
        insert message;
        
        //act
        Broker.executeResolvePersist(message.Id);
        
        //assemble 
        Message__c messageActual = [SELECT id, Message__c FROM Message__c WHERE id = :message.Id];
        
        //assert
        String actualMessage = messageActual.Message__c;
        String expectedMessage = 'ChainStep';
        System.assert(actualMessage.contains(expectedMessage), actualMessage);
    }
    
    static testMethod void testProcessWithoutClassThrowsThrowsExpectedException() {
        //arrange processes
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        
        //arrange chain
        Chain__c chain = new Chain__c(Name = 'TestChain');
        insert chain;
        
        //arrange steps
        ChainSteps.generateOne(chain.Id, terminateProcess.Id);
        
        terminateProcess.FullyQualifiedClassName__c = 'lalala';
        update terminateProcess; //pretend we deleted the class
        
        //act
        Test.startTest();
        Broker.enqueue(chain.Name, '000000000000000AAA');
        Test.stopTest();
        
        //assemble
        Message__c message = [SELECT Message__c FROM Message__c];
        
        //assert
        String actualMessage = message.Message__c;
        String expectedMessage = 'class missing';
        System.assert(actualMessage.contains(expectedMessage), actualMessage);
    }
    
    static testMethod void testNonProcessPluginThrowsTypeException() {
        //arrange processes
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        
        //arrange chain
        Chain__c chain = new Chain__c(Name = 'TestChain');
        insert chain;
        
        //arrange step
        ChainSteps.generateOne(chain.Id, terminateProcess.Id);
        
        terminateProcess.FullyQualifiedClassName__c = 'Account';
        update terminateProcess; //Account is DEFINITELY not a Process.Plugin
        
        //act
        Test.startTest();
        Broker.enqueue(chain.Name, '000000000000000AAA');
        Test.stopTest();
        
        //assert
        Message__c message = [SELECT Message__c FROM Message__c];
        String actualMessage = message.Message__c;
        String expectedMessage = 'interface';
        System.assert(actualMessage.contains(expectedMessage), actualMessage);
    }
    
    
    static testMethod void canGenerateUniqueIds() {
        // arrange 
        Integer uniqueTotal = 20000;
        Integer len = 10; // for len=5, Expected: 10000, Actual: 9944
        
        // act
        Set<String> uniqueIds =  new Set<String>();
        Integer count = 1;
        while (count <= uniqueTotal) {
            uniqueIds.add(Broker.getNotificationId(len));
            count++;
        }

        // assert
        Integer expectedSize = uniqueTotal;
        Integer actualSize = uniqueIds.size();
        System.assertEquals(expectedSize, actualSize);
    }
}