@isTest private class FutureBrokerTest {
    
    static public Boolean flagRestartImpl = false;
    class ToolingApiMock implements WebServiceMock {
        public void doInvoke(Object stub, Object request, Map<String, Object> response, String endpoint, String soapAction, String requestName, String responseNS, String responseName, String responseType) {
            flagRestartImpl = true;
            Api.executeAnonymousResponse_element responseElement = new Api.executeAnonymousResponse_element();
            responseElement.result = new Api.ExecuteAnonymousResult();
            responseElement.result.success = true;
            response.put('response_x', responseElement);
        }
    }
    
    public class MockFutureBroker extends FutureBroker {
        override public void restartImpl() {
            this.start();
        }
        
        override public void start() {
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
        Process__c markProcess = Processes.generateOne(Mark.class);
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        
        //arrange sequence
        String sequenceNameA = 'sequenceA';
        Sequence__c sequenceA = new Sequence__c(Name = sequenceNameA);
        insert sequenceA;
        
        //arrange steps
        Step__c stepA1 = Steps.generateOne(sequenceA.Id, markProcess.Id);
        Step__c stepA2 = Steps.generateOne(sequenceA.Id, terminateProcess.Id);
        Decimal positionA1 = stepA1.Position__c;
        Decimal positionA2 = stepA2.Position__c;
        
        //arrange concrete implementation
        insert new BrokerSettings__c(BrokerClassName__c = FutureBroker.class.getName());
        
        //assert
        Boolean expectedBeforeFlag = false;
        Boolean actualBeforeFlag = flagRestartImpl;
        System.assertEquals(expectedBeforeFlag, actualBeforeFlag);
        
        //act
        Test.startTest();
        Test.setMock(WebServiceMock.class, new ToolingApiMock());
        Broker.enqueue(sequenceNameA, '000000000000000AAA');
        Test.stopTest();
        
        //assert
        Boolean expectedAfterFlag = true;
        Boolean actualAfterFlag = flagRestartImpl;
        System.assertEquals(expectedAfterFlag, actualAfterFlag);
        
        //assemble
        List<Message__c> messages = [
            SELECT id, Name, Process__r.Name, Step__c , Status__c, IsDeleted
            FROM Message__c
            WHERE IsDeleted = false
            ALL ROWS
        ];
        
        //assert (note: the execution won't happen in test mode because it takes place in a web service callout)
        Integer expectedCount = 1;
        Integer actualCount = messages.size();
        System.assertEquals(expectedCount , actualCount);
    }
    
    static testMethod void callingBrokerRestartSuccessfullyCallsRestartImpl() {
        //arrange processes
        Process__c markProcess = Processes.generateOne(Mark.class);
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        
        //arrange sequence
        String sequenceNameA = 'sequenceA';
        Sequence__c sequenceA = new Sequence__c(Name = sequenceNameA);
        insert sequenceA;
        
        //arrange steps
        Step__c stepA1 = Steps.generateOne(sequenceA.Id, markProcess.Id);
        Step__c stepA2 = Steps.generateOne(sequenceA.Id, terminateProcess.Id);
        Decimal positionA1 = stepA1.Position__c;
        Decimal positionA2 = stepA2.Position__c;
        
        //arrange concrete broker implementation
        insert new BrokerSettings__c(BrokerClassName__c = FutureBroker.class.getName());
        
        // scenario:
        // resolved state , assume manual intervention to set status to 'Reprocess'
        Map<String,Object> parameters = new Map<String,Object> {
            'eda_sequenceName' => sequenceNameA,
            'eda_position' => 1, //not zero!!!
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
        Test.setMock(WebServiceMock.class, new ToolingApiMock());
        new FutureBroker().restartIfWorkPending();
        Test.stopTest();
        
        //assert
        Boolean expectedAfterFlag = true;
        Boolean actualAfterFlag = flagRestartImpl;
        System.assertEquals(expectedAfterFlag, actualAfterFlag);
        
        //assemble
        List<Message__c> messages = [
            SELECT id, Name, Process__r.Name, Step__c , Status__c, isDeleted
            FROM Message__c
            WHERE isDeleted = false
            ALL ROWS
        ];
        
        //assert (note: the execution won't happen in test mode because it takes place in a web service callout)
        Integer expectedCount = 1;
        Integer actualCount = messages.size();
        System.assertEquals(expectedCount, actualCount);
    }

    static testMethod void callingEnqueueWithInternallyFailingPluginSuccessfullyWritesErrorMessageToMessage() {
        //arrange process
        Process__c failureProcess = Processes.generateOne(BrokerTest.FailurePlugin.class);
        
        //arrange sequence
        String sequenceNameA = 'sequenceA';
        Sequence__c sequenceA = new Sequence__c(Name = sequenceNameA);
        insert sequenceA;
        
        //arrange step
        Step__c stepA1 = Steps.generateOne(sequenceA.Id, failureProcess.Id);
        Decimal positionA1 = stepA1.Position__c;
        
        //arrange specific broker implementation
        insert new BrokerSettings__c(BrokerClassName__c = MockFutureBroker.class.getName() );
        
        //act
        Test.startTest();
        Broker.enqueue(sequenceNameA, '000000000000000AAA');
        Test.stopTest();
        
        //assemble
        List<Message__c> messages = [
            SELECT id, Name, Process__r.FullyQualifiedClassName__c, Step__c , Status__c, Message__c, isDeleted
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
        System.assertEquals(expectedMessage, messages[0].Message__c );
    }
}