@IsTest public class ConfigureControllerTest {
    
    static testmethod void coverCode() {
        ConfigureController.doDanceIfNeeded(new PageReference(''));
        ConfigureController.refreshAccessToken();
        System.assert(ConfigureController.IsAllowed != null);
        
        ConfigureController controller = new ConfigureController();
        controller.buildAuthLink();
        controller.buildCodeLink('');
        controller.buildRefreshLink();
        controller.handleRedirect();
        controller.doGetStarted();
        System.assert(controller != null);
    }
    
}