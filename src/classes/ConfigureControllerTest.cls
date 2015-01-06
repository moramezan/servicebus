@IsTest public class ConfigureControllerTest {
    
    class CalloutResponder implements HttpCalloutMock {
        public System.HttpResponse respond(System.HttpRequest request) {
            return new System.HttpResponse();
        }
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