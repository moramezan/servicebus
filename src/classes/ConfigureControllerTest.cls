@IsTest public class ConfigureControllerTest {
    
    static testmethod void testIsAllowed() {
        //assert
        System.assert(!ConfigureController.IsAllowed);
    }
    
    static testmethod void testDanceIfNeeded() {
        //arrange
        PageReference retURL = new PageReference('/home/home.jsp');
        
        //act
        PageReference pr = ConfigureController.doDanceIfNeeded(retURL);
        
        //assert
        System.assert(pr != null);
    }
    
    static testmethod void testBuildAuthLink() {
        //arrange controller
        ConfigureController controller = new ConfigureController();
        
        //act
        PageReference pr = controller.buildAuthLink();
        
        //assert
        System.assert(pr.getUrl().contains('/services/oauth2/authorize'));
        System.assert(pr.getUrl().contains('response_type'));
        System.assert(pr.getUrl().contains('client_id'));
        System.assert(pr.getUrl().contains('redirect_uri'));
    }
    
    static testmethod void testBuildCodeLink() {
        //arrange
        ConfigureController controller = new ConfigureController();
        
        //act
        PageReference pr = controller.buildCodeLink('12345');
        
        //assert
        System.assert(pr.getUrl().contains('/services/oauth2/token'));
        System.assert(pr.getUrl().contains('grant_type'));
        System.assert(pr.getUrl().contains('client_id'));
        System.assert(pr.getUrl().contains('client_secret'));
        System.assert(pr.getUrl().contains('redirect_uri'));
        System.assert(pr.getUrl().contains('code'));
        System.assert(pr.getUrl().contains('format'));
    }
    
    static testmethod void testBuildRefreshLink() {
        //arrange
        ConfigureController controller = new ConfigureController();
        
        //act
        PageReference pr = controller.buildRefreshLink();
        
        //assert
        System.assert(pr.getUrl().contains('/services/oauth2/token'));
        System.assert(pr.getUrl().contains('grant_type'));
        System.assert(pr.getUrl().contains('client_id'));
        System.assert(pr.getUrl().contains('client_secret'));
        System.assert(pr.getUrl().contains('refresh_token'));
    }
    
    @TestVisible private class HttpCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('{"refresh_token":"ABCDE","access_token":"12345"}');
            return response;
        }
    }
    
    static testmethod void testHandleRedirect() {
        //arrange page
        PageReference current = new PageReference('/?code=code');
        Test.setCurrentPageReference(current);
        
        //arrange controller
        ConfigureController controller = new ConfigureController();
        
        //act
        Test.setMock(HttpCalloutMock.class, new HttpCallout());
        PageReference pr = controller.handleRedirect();
        
        //assert
        String expectedRunningUerId = UserInfo.getUserId();
        String actualRunningUerId = OAuthSetting__c.getOrgDefaults().RunningUserId__c;
        System.assertEquals(expectedRunningUerId, actualRunningUerId, 'Running User Id not set.');
        
        String expectedAccessToken = '12345';
        String actualAccessToken = OAuthSetting__c.getOrgDefaults().AccessToken__c;
        System.assertEquals(expectedAccessToken, actualAccessToken, 'Access token not set.');

        String expectedRefreshToken = 'ABCDE';
        String actualRefreshToken = OAuthSetting__c.getOrgDefaults().RefreshToken__c;
        System.assertEquals(expectedRefreshToken, actualRefreshToken, 'Refresh token not set.');
    }
    
    static testmethod void testGetStarted() {
        //arrange
        ConfigureController controller = new ConfigureController();
        
        //act
        PageReference pr = controller.doGetStarted();
        
        //assert
        System.assert(pr.getUrl().contains('tsid'));
    }
    
    static testmethod void testPermissionSetAssignmentCreated() {
        //arrange new user
        User user = new User(
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id,
            Username = DateTime.now().getTime() + 'test@test.com',
            Alias = 'mgr',
            LastName = 'Test',
            LocaleSidKey = 'en_US',
            Email = 'test@example.com',
            CommunityNickname = 'mgr',
            LanguageLocaleKey = 'en_US',
            EmailEncodingKey = 'ISO-8859-1',
            TimeZoneSidKey = 'Australia/Sydney'
        );
        insert user;
        
        System.runAs(user) {
            //act
            Test.startTest();
            Integer countBefore = [SELECT COUNT() FROM PermissionSetAssignment WHERE AssigneeId = :user.Id];
            ConfigureController.assignPermissionSet(user.Id);
            Test.stopTest();
            
            //assert
            Integer expectedCount = countBefore + 1;
            Integer actualCount = [SELECT COUNT() FROM PermissionSetAssignment WHERE AssigneeId = :user.Id];
            System.assertEquals(expectedCount, actualCount);
        }
    }
    
    static testmethod void testWiretapSettingsCreated() {
        //arrange user
        Id userId = UserInfo.getUserId();
        
        //act
        Test.startTest();
        Integer countBefore = [SELECT COUNT() FROM WiretapSetting__c];
        ConfigureController.createWiretapSettings(userId);
        Test.stopTest();
        
        //assert
        Integer expectedCount = countBefore + 1;
        Integer actualCount = [SELECT COUNT() FROM WiretapSetting__c];
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testmethod void callingInstallScheduleCorrectlyInstallsSchedule() {
        //arrange
        String  name = 'Enterprise Service Bus Heartbeat';
        
        //act
        ConfigureController.reinstallSchedule();
        
        //assert
        Integer expectedSizeAfter = 1;
        Integer actualSizeAfter = [SELECT COUNT() FROM CronJobDetail WHERE Name = :name LIMIT 1];
        System.assertEquals(expectedSizeAfter, actualSizeAfter);
        
    }
}