@IsTest public class ConfigureControllerTest {
    
    class CalloutResponder implements HttpCalloutMock {
        public System.HttpResponse respond(System.HttpRequest request) {
            return new System.HttpResponse();
        }
    }
    
    static testmethod void testGetHasAppAlwaysFalseInTest() {
        //arrange
        ConfigureController controller = new ConfigureController();
        
        //act
        Boolean hasApp = controller.getHasApp();
        
        //assert
        System.assert(!hasApp);
    }
    
    static testmethod void testDoSetupAppReturnsAppIdInUrl() {
        //arrange
        ConfigureController controller = new ConfigureController();
        
        //act
        String url = controller.doSetupApp().getUrl();
        
        //assert
        System.assert(url.contains('02u'));
        System.assert(url.contains('00e'));
    }
    
    static testmethod void testGetHasHeartbeatFalseInTest() {
        //arrange
        ConfigureController controller = new ConfigureController();
        Integer expectedCount = [SELECT COUNT() FROM CronJobDetail WHERE Name = 'Heartbeat (do not delete)'];
        
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
    
    static testmethod void testGetHasRemoteSite() {
        //arrange
        ConfigureController controller = new ConfigureController();
        Test.setMock(HttpCalloutMock.class, new CalloutResponder());
        
        //act
        Boolean hasRemoteSite = controller.getHasRemoteSite();
        
        //assert
        System.assert(hasRemoteSite);
    }
    
    static testmethod void testDoSetupRemoteSite() {
        //arrange
        ConfigureController controller = new ConfigureController();
        
        //act
        String url = controller.doSetupRemoteSite().getUrl();
        
        //assert
        System.assert(url.contains('0rp'));
        System.assert(url.contains('ESB'));
        System.assert(url.contains('installation'));
    }
    
}