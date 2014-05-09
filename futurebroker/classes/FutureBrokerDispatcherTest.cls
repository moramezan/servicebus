@isTest public class FutureBrokerDispatcherTest {
    
    class RestartableMock implements FutureBrokerDispatcher.Restartable {
        public void restart(String sessionId) {
            //
        }
    }
    
    static testMethod void coverInterface() {
        Object mock = new RestartableMock();
        System.assert(mock instanceof FutureBrokerDispatcher.Restartable);
    }
    
    static public Boolean isCalled = false;
    class FutureBrokerClientMock implements WebServiceMock {
        public void doInvoke(Object stub, Object request, Map<String, Object> response, String endpoint, String soapAction, String requestName, String responseNS, String responseName, String responseType) {
            isCalled = true;
            FutureBrokerClient.doStartResponse responseElement = new FutureBrokerClient.doStartResponse();
            response.put('response_x', responseElement);
        }
    }
    
    static testMethod void testRestart() {
        //act
        Test.startTest();
        Test.setMock(WebServiceMock.class, new FutureBrokerClientMock());
        FutureBrokerDispatcher.restart(UserInfo.getSessionId());
        Test.stopTest();
        
        //assert
        Boolean expectedAfterFlag = true;
        Boolean actualAfterFlag = isCalled;
        System.assertEquals(expectedAfterFlag, actualAfterFlag);
    }
    
}