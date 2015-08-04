@IsTest public class RemoteSiteSettingControllerTest {

    static testmethod void testDeployXml() {
        //arrange controller
        RemoteSiteSettingController controller = new RemoteSiteSettingController();
        
        //act
        String deployXml = controller.getDeployXml();
        
        //assert
        System.assert(deployXml.contains(UserInfo.getSessionId()));
        System.assert(deployXml.contains(Url.getSalesforceBaseUrl().toExternalForm()));
    }

}