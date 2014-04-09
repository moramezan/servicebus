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
    class ToolingApiMock implements WebServiceMock {
        public void doInvoke(Object stub, Object request, Map<String, Object> response, String endpoint, String soapAction, String requestName, String responseNS, String responseName, String responseType) {
            isCalled = true;
            Api.executeAnonymousResponse_element responseElement = new Api.executeAnonymousResponse_element();
            responseElement.result = new Api.ExecuteAnonymousResult();
            responseElement.result.success = true;
            response.put('response_x', responseElement);
        }
    }
    
    static testMethod void testRestart() {
        //act
        Test.startTest();
        Test.setMock(WebServiceMock.class, new ToolingApiMock());
        FutureBrokerDispatcher.restart(UserInfo.getSessionId());
        Test.stopTest();
        
        //assert
        Boolean expectedAfterFlag = true;
        Boolean actualAfterFlag = isCalled;
        System.assertEquals(expectedAfterFlag, actualAfterFlag);
    }
    
}