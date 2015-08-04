@IsTest public class ConfigureControllerTest {
    
    static testmethod void testRefreshAccessTokenMissingRemoteSiteSetting() {
        //arrange custom setting
        OAuthSetting__c setting = OAuthSetting__c.getOrgDefaults();
        setting.InstanceUrl__c = 'https://localhost'; //not allowed
        insert setting;
        
        //arrange schedule
        ConfigureController.reinstallSchedule();
        
        //assert schedule is started
        Integer expectedCount = 1;
        Integer actualCount = [SELECT COUNT() FROM CronJobDetail WHERE Name = :ConfigureController.JobName];
        System.assertEquals(expectedCount, actualCount, 'Wrong schedule count before.');
        
        //assert setting is present
        expectedCount = 1;
        actualCount = [SELECT COUNT() FROM OAuthSetting__c];
        System.assertEquals(expectedCount, actualCount, 'Wrong setting count before.');
        
        //act
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new UnauthorizedEndpointResponse());
        ConfigureController.refreshAccessToken();
        Test.stopTest();
        
        //assert that schedule is stopped
        expectedCount = 0;
        actualCount = [SELECT COUNT() FROM CronJobDetail WHERE Name = :ConfigureController.JobName];
        System.assertEquals(expectedCount, actualCount, 'Wrong count after.');
        
        //assert setting is absent
        expectedCount = 0;
        actualCount = [SELECT COUNT() FROM OAuthSetting__c];
        System.assertEquals(expectedCount, actualCount, 'Wrong setting count after.');
    }
    
    static testmethod void testBuildAuthLink() {
        //arrange controller
        ConfigureController controller = new ConfigureController();
        
        //act
        System.PageReference pr = controller.buildAuthLink();
        
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
        System.PageReference pr = controller.buildCodeLink('12345');
        
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
        System.PageReference pr = controller.buildRefreshLink();
        
        //assert
        System.assert(pr.getUrl().contains('/services/oauth2/token'));
        System.assert(pr.getUrl().contains('grant_type'));
        System.assert(pr.getUrl().contains('client_id'));
        System.assert(pr.getUrl().contains('client_secret'));
        System.assert(pr.getUrl().contains('refresh_token'));
    }
    
    static testmethod void testDoRedirectStageNull() {
        //arrange controller and page
        ConfigureController controller = new ConfigureController();
        Test.setCurrentPage(Page.Configure);
        
        //act
        System.PageReference redirect = controller.doRedirect();
        
        //assert
        String expectedLid = [SELECT Id FROM WebLink WHERE Description = 'Enterprise Service Bus configuration link.'].Id;
        String actualLid = redirect.getParameters().get('lid');
        System.assertEquals(expectedLid, actualLid, 'Wrong lid.');
    }
    
    static testmethod void testDoRedirectStageCustomSetting() {
        //arrange controller and page
        ConfigureController controller = new ConfigureController();
        System.PageReference configure = Page.Configure;
        configure.getParameters().put('url', Url.getSalesforceBaseUrl().toExternalForm() + '/services/Soap/c/34.0'); //this implies stage=cs
        Test.setCurrentPage(configure);
        
        //act
        System.PageReference redirect = controller.doRedirect();
        
        //assert
        Integer expectedCount = 1;
        Integer actualCount = [SELECT COUNT() FROM OAuthSetting__c];
        System.assertEquals(expectedCount, actualCount, 'Wrong custom setting count.');
        
        String expectedUrl = Page.Configure.getUrl() + '?stage=js';
        String actualUrl = redirect.getUrl();
        System.assertEquals(expectedUrl, actualUrl, 'Wrong redirect.');
        
        String expectedBase = Url.getSalesforceBaseUrl().toExternalForm();
        String actualBase = OAuthSetting__c.getOrgDefaults().InstanceUrl__c;
        System.assertEquals(expectedBase, actualBase, 'Wrong base.');
        
        String expectedUnprefixedOrgId = UserInfo.getOrganizationId().substring(3, 15);
        String actualUnprefixedOrgId = OAuthSetting__c.getOrgDefaults().UnprefixedOrgId__c;
        System.assertEquals(expectedUnprefixedOrgId, actualUnprefixedOrgId, 'Wrong id.');
    }
    
    static testmethod void testDoRedirectStageJavaScript() {
        //arrange controller and page
        ConfigureController controller = new ConfigureController();
        System.PageReference configure = Page.Configure;
        configure.getParameters().put('stage', 'js');
        Test.setCurrentPage(configure);
        
        //act
        System.PageReference redirect = controller.doRedirect();
        
        //assert
        System.PageReference expectedRedirect  = null;
        System.PageReference actualRedirect = redirect;
        System.assertEquals(expectedRedirect, actualRedirect, 'Not null.');
    }
    
    static testmethod void testDoRedirectStageOAuth() {
        //arrange controller and page
        ConfigureController controller = new ConfigureController();
        System.PageReference configure = Page.Configure;
        configure.getParameters().put('stage', 'oa');
        Test.setCurrentPage(configure);
        
        //act
        System.PageReference redirect = controller.doRedirect();
        
        //assert
        String expectedUrl = controller.buildAuthLink().getUrl();
        String actualUrl = redirect.getUrl();
        System.assertEquals(expectedUrl, actualUrl, 'Wrong URL.');
    }
    
    static testmethod void testDoRedirectStageCallBack() {
        //arrange controller and page
        ConfigureController controller = new ConfigureController();
        System.PageReference configure = Page.Configure;
        configure.getParameters().put('code', '12345'); //this implies stage=cb
        Test.setCurrentPage(configure);
        
        //act
        Test.setMock(HttpCalloutMock.class, new TokenResponse());
        System.PageReference redirect = controller.doRedirect();
        
        //assert
        String expectedUrl = new System.PageReference('/apex/ContextSensitiveHelp?topic=EnterpriseServiceBus').getUrl();
        String actualUrl = redirect.getUrl();
        System.assertEquals(expectedUrl, actualUrl, 'Wrong URL.');
        
        Id expectedUserId = UserInfo.getUserId();
        Id actualUserId = OAuthSetting__c.getOrgDefaults().RunningUserId__c;
        System.assertEquals(expectedUserId, actualUserId, 'Wrong running user id.');
        
        String expectedRefreshToken = 'rrrrr';
        String actualRefreshToken = OAuthSetting__c.getOrgDefaults().RefreshToken__c;
        System.assertEquals(expectedRefreshToken, actualRefreshToken, 'Wrong refresh token.');
        
        String expectedAccessToken = 'aaaaa';
        String actualAccessToken = OAuthSetting__c.getOrgDefaults().AccessToken__c;
        System.assertEquals(expectedAccessToken, actualAccessToken, 'Wrong access token.');
    }
    
    static testmethod void testDoRedirectStageCallBackIpRestricted() {
        //arrange controller and page
        ConfigureController controller = new ConfigureController();
        System.PageReference configure = Page.Configure;
        configure.getParameters().put('code', '12345'); //this implies stage=cb
        Test.setCurrentPage(configure);
        
        //act
        Test.setMock(HttpCalloutMock.class, new IpRestrictedResponse());
        System.PageReference redirect = controller.doRedirect();
        
        //assert
        String expectedUrl = new System.PageReference('/packaging/installPackage.apexp?p0=04tj0000001Z2IU').getUrl();
        String actualUrl = redirect.getUrl();
        System.assertEquals(expectedUrl, actualUrl, 'Wrong URL.');
    }
    
    @TestVisible private class UnauthorizedEndpointResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            CalloutException e = (CalloutException)CalloutException.class.newInstance();
            e.setMessage('Unauthorized endpoint, please check Setup->Security->Remote site settings.');
            throw e;
        }
    }
    
    @TestVisible private class IpRestrictedResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setBody('{"error_description":"ip restricted","error":"invalid_grant"}');
            return response;
        }
    }
    
    @TestVisible private class TokenResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            ConfigureController.Token token = new ConfigureController.Token();
            token.refresh_token = 'rrrrr';
            token.access_token = 'aaaaa';
            
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody(Json.serialize(token));
            return response;
        }
    }
}