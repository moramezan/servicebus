@isTest private class FutureBrokerImplementationTest {
    
    static testMethod void testPodProtocolAndHost() {
        FutureBrokerImplementation.IdentityResult result = new FutureBrokerImplementation.IdentityResult();
        String expectedProtocolAndHost = Url.getSalesforceBaseUrl().toExternalForm();
        String actualProtocolAndHost = new FutureBrokerImplementation().podProtocolAndHost();
        System.assertEquals(expectedProtocolAndHost, actualProtocolAndHost);
    }
    
    static public Boolean flagRestartImpl = false;
    class FutureBrokerClientMock implements WebServiceMock {
        public void doInvoke(Object stub, Object request, Map<String, Object> response, String endpoint, String soapAction, String requestName, String responseNS, String responseName, String responseType) {
            flagRestartImpl = true;
            FutureBrokerClient.doStartResponse responseElement = new FutureBrokerClient.doStartResponse();
            response.put('response_x', responseElement);
        }
    }
    
    public class MockFutureBrokerImplementation extends FutureBrokerImplementation {
        override public void restartImpl() {
            this.handleStart();
        }
        
        override public void handleStart() {
            //start (MARK)
            Database.QueryLocator locator = this.locateMarkedWork(5); //note that markImpl is called inside this method
            Database.QueryLocatorIterator iterator = locator.iterator();
            
            //execute (EXECUTE, RESOLVE, PERSIST)
            while (iterator.hasNext()) {
                Message__c message = (Message__c)iterator.next();
                Broker.executeResolvePersist(message.Id);
            }
            
            //finish (invokes broker in a @future)
            this.restartIfWorkPending();
        }
        
        override public void markImpl(Set<Id> messageIds) {
            Broker.Mark(messageIds);
        }
    }
    
    static testMethod void callingEnqueueSuccessfullyCallRestartImp() {
        //arrange processes
        Process__c markProcess = ProcessSet.generateOne(Mark.class);
        Process__c terminateProcess = ProcessSet.generateOne(Terminate.class);
        
        //arrange sequence
        String sequenceNameA = 'sequenceA';
        Sequence__c sequenceA = new Sequence__c(Name = sequenceNameA);
        insert sequenceA;
        
        //arrange steps
        Step__c stepA1 = StepSet.generateOne(sequenceA.Id, markProcess.Id);
        Step__c stepA2 = StepSet.generateOne(sequenceA.Id, terminateProcess.Id);
        Decimal positionA1 = stepA1.Position__c;
        Decimal positionA2 = stepA2.Position__c;
        
        //arrange concrete implementation
        insert new BrokerSettings__c(BrokerClassName__c = FutureBrokerImplementation.class.getName());
        
        //assert
        Boolean expectedBeforeFlag = false;
        Boolean actualBeforeFlag = flagRestartImpl;
        System.assertEquals(expectedBeforeFlag, actualBeforeFlag);
        
        //act
        Test.startTest();
        Test.setMock(WebServiceMock.class, new FutureBrokerClientMock());
        Broker.enqueue(sequenceNameA, '000000000000000AAA');
        Test.stopTest();
        
        //assert
        Boolean expectedAfterFlag = true;
        Boolean actualAfterFlag = flagRestartImpl;
        System.assertEquals(expectedAfterFlag, actualAfterFlag);
        
        //assert (note: the execution won't happen in test mode because it takes place in a web service callout)
        Integer expectedCount = 1;
        Integer actualCount = [SELECT COUNT() FROM Message__c WHERE IsDeleted = false ALL ROWS];
        System.assertEquals(expectedCount , actualCount);
    }
    
    static testMethod void callingBrokerRestartSuccessfullyCallsRestartImpl() {
        //arrange processes
        Process__c markProcess = ProcessSet.generateOne(Mark.class);
        Process__c terminateProcess = ProcessSet.generateOne(Terminate.class);
        
        //arrange sequence
        String sequenceNameA = 'sequenceA';
        Sequence__c sequenceA = new Sequence__c(Name = sequenceNameA);
        insert sequenceA;
        
        //arrange steps
        Step__c stepA1 = StepSet.generateOne(sequenceA.Id, markProcess.Id);
        Step__c stepA2 = StepSet.generateOne(sequenceA.Id, terminateProcess.Id);
        Decimal positionA1 = stepA1.Position__c;
        Decimal positionA2 = stepA2.Position__c;
        
        //arrange concrete broker implementation
        insert new BrokerSettings__c(BrokerClassName__c = FutureBrokerImplementation.class.getName());
        
        // scenario:
        // resolved state , assume manual intervention to set status to 'Reprocess'
        Map<String,Object> parameters = new Map<String,Object> {
            'eda_SequenceName' => sequenceNameA,
            'eda_Position' => 1, //not zero!!!
            'Id' => '000000000000000AAA'
        };
        Message__c message = new Message__c(
            Step__c = stepA1.Id,
            Status__c = 'Reprocess',
            Parameters__c = Json.serializePretty(parameters)
        );
        insert message;
        
        //assert
        Boolean expectedBeforeFlag = false;
        Boolean actualBeforeFlag = flagRestartImpl;
        System.assertEquals(expectedBeforeFlag, actualBeforeFlag);
        
        //act
        Test.startTest();
        Test.setMock(WebServiceMock.class, new FutureBrokerClientMock());
        new FutureBrokerImplementation().restartIfWorkPending();
        Test.stopTest();
        
        //assert
        Boolean expectedAfterFlag = true;
        Boolean actualAfterFlag = flagRestartImpl;
        System.assertEquals(expectedAfterFlag, actualAfterFlag);
        
        //assert (note: the execution won't happen in test mode because it takes place in a web service callout)
        Integer expectedCount = 1;
        Integer actualCount = [SELECT COUNT() FROM Message__c WHERE isDeleted = false ALL ROWS];
        System.assertEquals(expectedCount, actualCount);
    }

    static testMethod void callingEnqueueWithInternallyFailingPluginSuccessfullyWritesErrorMessageToMessage() {
        //arrange process
        Process__c failureProcess = ProcessSet.generateOne(BrokerTest.FailurePlugin.class);
        
        //arrange sequence
        String sequenceNameA = 'sequenceA';
        Sequence__c sequenceA = new Sequence__c(Name = sequenceNameA);
        insert sequenceA;
        
        //arrange step
        Step__c stepA1 = StepSet.generateOne(sequenceA.Id, failureProcess.Id);
        Decimal positionA1 = stepA1.Position__c;
        
        //arrange specific broker implementation
        insert new BrokerSettings__c(BrokerClassName__c = MockFutureBrokerImplementation.class.getName() );
        
        //act
        Test.startTest();
        Broker.enqueue(sequenceNameA, '000000000000000AAA');
        Test.stopTest();
        
        //assemble
        List<Message__c> messages = [
            SELECT id, Name, Process__r.FullyQualifiedClassName__c, Step__c , Status__c, Exception__c, isDeleted
            FROM Message__c
            WHERE isDeleted = false
            ALL ROWS
        ];
        Integer actualCount = messages.size();
        
        //assert
        Integer expectedCount = 1;
        System.assertEquals(expectedCount , actualCount);
        
        String expectedProcessName = BrokerTest.FailurePlugin.class.getName();
        System.assertEquals(expectedProcessName, messages[0].Process__r.FullyQualifiedClassName__c);
        
        String expectedMessage = BrokerTest.FailureMessage;
        System.assertEquals(expectedMessage, messages[0].Exception__c );
    }
    
}