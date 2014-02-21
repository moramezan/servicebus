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
                PersistentData__c persistentData = (PersistentData__c)iterator.next();
                Broker.executeResolvePersist(persistentData.Id);
            }
            
            //finish (invokes broker in a @future)
            this.restartIfWorkPending();
        }
        
        override public void markImpl(Set<Id> persistentDataIds) {
            Broker.Mark(persistentDataIds);
        }
    }
    
    static testMethod void callingEnqueueSuccessfullyCallRestartImp() {
        //arrange processes
        Process__c markProcess = Processes.generateOne(Mark.class);
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        
        //arrange chain
        String chainNameA = 'chainA';
        Chain__c chainA = new Chain__c(Name = chainNameA);
        insert chainA;
        
        //arrange steps
        ChainStep__c stepA1 = ChainSteps.generateOne(chainA.Id, markProcess.Id);
        ChainStep__c stepA2 = ChainSteps.generateOne(chainA.Id, terminateProcess.Id);
        Decimal sequenceA1 = stepA1.Sequence__c;
        Decimal sequenceA2 = stepA2.Sequence__c;
        
        //arrange concrete implementation
        insert new BrokerSettings__c(BrokerClassName__c = FutureBroker.class.getName());
        
        //assert
        Boolean expectedBeforeFlag = false;
        Boolean actualBeforeFlag = flagRestartImpl;
        System.assertEquals(expectedBeforeFlag, actualBeforeFlag);
        
        //act
        Test.startTest();
        Test.setMock(WebServiceMock.class, new ToolingApiMock());
        Broker.enqueue(chainNameA, '000000000000000AAA');
        Test.stopTest();
        
        //assert
        Boolean expectedAfterFlag = true;
        Boolean actualAfterFlag = flagRestartImpl;
        System.assertEquals(expectedAfterFlag, actualAfterFlag);
        
        //assemble
        List<PersistentData__c> persistentDatas = [
            SELECT id, Name, Process__r.Name, ChainStep__c , Status__c, IsDeleted
            FROM PersistentData__c
            WHERE IsDeleted = false
            ALL ROWS
        ];
        
        //assert (note: the execution won't happen in test mode because it takes place in a web service callout)
        Integer expectedCount = 1; 
        Integer actualCount = persistentDatas.size();
        System.assertEquals(expectedCount , actualCount); 
    }
    
    static testMethod void callingBrokerRestartSuccessfullyCallsRestartImpl() {
        //arrange processes
        Process__c markProcess = Processes.generateOne(Mark.class);
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        
        //arrange chain
        String chainNameA = 'chainA';
        Chain__c chainA = new Chain__c(Name = chainNameA);
        insert chainA;
        
        //arrange steps
        ChainStep__c stepA1 = ChainSteps.generateOne(chainA.Id, markProcess.Id);
        ChainStep__c stepA2 = ChainSteps.generateOne(chainA.Id, terminateProcess.Id);
        Decimal sequenceA1 = stepA1.Sequence__c;
        Decimal sequenceA2 = stepA2.Sequence__c;
        
        //arrange concrete broker implementation
        insert new BrokerSettings__c(BrokerClassName__c = FutureBroker.class.getName());
        
        // scenario:
        // resolved state , assume manual intervention to set status to 'Reprocess'
        Map<String,Object> notification = new Map<String,Object> {
            'eda__chainName' => chainNameA,
            'eda__sequence' => 1, //not zero!!!
            'id' => '000000000000000AAA'
        };
        PersistentData__c persistentData = new PersistentData__c(
            ChainStep__c = stepA1.Id,
            Status__c = 'Reprocess',
            Notification__c = Json.serializePretty(notification)
        );
        insert persistentData;
        
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
        List<PersistentData__c> persistentDatas = [
            SELECT id, Name, Process__r.Name, ChainStep__c , Status__c, isDeleted 
            FROM PersistentData__c 
            WHERE isDeleted = false
            ALL ROWS
        ];
        
        //assert (note: the execution won't happen in test mode because it takes place in a web service callout)
        Integer expectedCount = 1;
        Integer actualCount = persistentDatas.size();
        System.assertEquals(expectedCount, actualCount);
    } 

    static testMethod void callingEnqueueWithInternallyFailingPluginSuccessfullyWritesErrorMessageToPersistentData() {
        //arrange process
        Process__c failureProcess = Processes.generateOne(FailurePlugin.class);
        
        //arrange chain
        String chainNameA = 'chainA';
        Chain__c chainA = new Chain__c(Name = chainNameA);
        insert chainA;
        
        //arrange step
        ChainStep__c stepA1 = ChainSteps.generateOne(chainA.Id, failureProcess.Id);
        Decimal sequenceA1 = stepA1.Sequence__c;
        
        //arrange specific broker implementation
        insert new BrokerSettings__c(BrokerClassName__c = MockFutureBroker.class.getName() );
        
        //act
        Test.startTest();
        Broker.enqueue(chainNameA, '000000000000000AAA');
        Test.stopTest();
        
        //assemble
        List<PersistentData__c> persistentDatas = [
            SELECT id, Name, Process__r.Name, ChainStep__c , Status__c, Message__c, isDeleted 
            FROM PersistentData__c 
            WHERE isDeleted = false
            ALL ROWS
        ];
        Integer actualCount = persistentDatas.size();
        
        //assert
        Integer expectedCount = 1; 
        System.assertEquals(expectedCount , actualCount); 
        
        String expectedProcessName = FailurePlugin.class.getName();
        System.assertEquals(expectedProcessName, persistentDatas[0].Process__r.Name);
        
        String expectedMessage = FailurePlugin.FailureMessage;
        System.assertEquals(expectedMessage, persistentDatas[0].Message__c );
    }
}