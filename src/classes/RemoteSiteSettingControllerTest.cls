@IsTest public class RemoteSiteSettingControllerTest {

    static testmethod void testProtocolAndHost() {
        //assert
        String expectedEndpoint = Url.getSalesforceBaseUrl().toExternalForm();
        String actualEndpoint = RemoteSiteSettingController.protocolAndHost;
        System.assertEquals(expectedEndpoint, actualEndpoint, 'Wrong endpoint.');
    }
    
    static testmethod void testIsRssPresent() {
        //assert
        System.assert(RemoteSiteSettingController.isRssPresent);
    }
    
    static testmethod void testDeployXml() {
        //arrange controller
        RemoteSiteSettingController controller = new RemoteSiteSettingController();
        
        //act
        String deployXml = controller.getDeployXml();
        
        //assert
        System.assert(deployXml.contains(UserInfo.getSessionId()));
        System.assert(deployXml.contains(RemoteSiteSettingController.protocolAndHost));
    }

}