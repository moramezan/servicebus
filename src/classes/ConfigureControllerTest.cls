@IsTest public class ConfigureControllerTest {
    
    class CalloutResponder implements HttpCalloutMock {
        public System.HttpResponse respond(System.HttpRequest request) {
            return new System.HttpResponse();
        }
    }
    
    static testmethod void coverAttemptCallout() {
        Test.setMock(HttpCalloutMock.class, new CalloutResponder());
        ConfigureController controller = new ConfigureController();
        Boolean ok = true;
        try {
            controller.attemptCallout('');
        } catch (Exception e) {
            ok = false;
        }
        System.assert(ok);
    }
    
    static testmethod void testBuildSetupPage() {
        ConfigureController controller = new ConfigureController();
        System.PageReference setup = controller.buildSetupPage();
        System.assert(setup.getUrl().contains('EndpointUrl=https'));
    }
    
    static testmethod void testPodProtocolAndHost() {
        ConfigureController.IdentityResult result = new ConfigureController.IdentityResult();
        String expectedProtocolAndHost = Url.getSalesforceBaseUrl().toExternalForm();
        String actualProtocolAndHost = ConfigureController.podProtocolAndHost();
        System.assertEquals(expectedProtocolAndHost, actualProtocolAndHost);
    }
    
}