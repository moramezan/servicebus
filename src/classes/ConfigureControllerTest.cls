@IsTest public class ConfigureControllerTest {
    
    class CalloutResponder implements HttpCalloutMock {
        public System.HttpResponse respond(System.HttpRequest request) {
            return new System.HttpResponse();
        }
    }
    
    static testmethod void testGetHasHeartbeatFalseInTest() {
        //arrange
        ConfigureController controller = new ConfigureController();
        Integer expectedCount = [SELECT COUNT() FROM CronJobDetail WHERE Name = 'Enterprise Service Bus Heartbeat'];
        
        //act
        Boolean hasHeartbeat = controller.getHasHeartbeat();
        
        
        //assert
        Boolean expected = expectedCount == 1;
        Boolean actual = hasHeartbeat;
        System.assertEquals(expected, actual);
    }
    
    static testmethod void testDoSetupHeartbeatSchedulesTheJob() {
        //arrange
        ConfigureController controller = new ConfigureController();
        
        //act
        controller.doSetupHeartbeat();
        
        //assert
        System.assert(controller.getHasHeartbeat());
    }
    
    static testmethod void testGetHasRemoteSiteSetting() {
        //arrange
        ConfigureController controller = new ConfigureController();
        Test.setMock(HttpCalloutMock.class, new CalloutResponder());
        
        //act
        controller.detectRemoteSiteSetting();
        Boolean hasRemoteSite = controller.HasRemoteSiteSetting;
        
        //assert
        System.assert(hasRemoteSite);
    }
    
}