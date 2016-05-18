@IsTest class ConfigureControllerTest {
    
    @TestSetup static void testSetup() {
        //act
        new PostInstallHandler().onInstall(null);
        
        //assert
        System.assertNotEquals(null, Application__c.getOrgDefaults().Id, 'Wrong id.');
    }
    
    static testmethod void testRefreshAccessTokenMissingRemoteSiteSetting() {
        //arrange custom setting
        Application__c application = Application__c.getOrgDefaults();
        application.OrgBaseUrl__c = 'https://herp.derp'; //not allowed
        upsert application;
        
        //arrange schedule
        ConfigureController.reinstallSchedule();
        
        //assert schedule is started
        Integer expectedCount = 1;
        Integer actualCount = [SELECT COUNT() FROM CronJobDetail WHERE Name = :ConfigureController.JobName];
        System.assertEquals(expectedCount, actualCount, 'Wrong schedule count before.');
        
        //assert setting is present
        expectedCount = 1;
        actualCount = [SELECT COUNT() FROM Application__c];
        System.assertEquals(expectedCount, actualCount, 'Wrong setting count before.');
        
        try {
            //act
            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new UnauthorizedEndpointResponse());
            String accessToken = ConfigureController.refreshAccessToken();
            Test.stopTest();
            System.assert(false, 'Line above should throw exception.');
        } catch (Exception e) {
            //assert
            String expectedMessage = 'Unauthorized endpoint';
            String actualMessage = e.getMessage();
            System.assert(actualMessage.contains(expectedMessage), 'Wrong message.');
        }
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
        PageReference configure = Page.Configure;
        configure.getParameters().put('retURL', '/foo/bar');
        Test.setCurrentPage(configure);
        
        //act
        System.PageReference redirect = controller.doRedirect();
        
        //assert
        String expectedLid = [SELECT Id FROM WebLink WHERE Description = 'Services configuration link.'].Id;
        String actualLid = redirect.getParameters().get('lid');
        System.assertEquals(expectedLid, actualLid, 'Wrong lid.');
        
        String expectedReturnUrl = '/foo/bar';
        String actualReturnUrl = redirect.getParameters().get('retURL');
        System.assertEquals(expectedLid, actualLid, 'Wrong return URL.');
    }
    
    static testmethod void testDoRedirectStageCustomSetting() {
        //arrange controller and page
        ConfigureController controller = new ConfigureController();
        System.PageReference configure = Page.Configure;
        configure.getParameters().put('url', Url.getSalesforceBaseUrl().toExternalForm().replace('http:', 'https:') + '/services/Soap/c/36.0'); //this implies stage=cs //#1188
        configure.getParameters().put('retURL', '/herp/derp');
        Test.setCurrentPage(configure);
        
        //act
        System.PageReference redirect = controller.doRedirect();
        
        //assert
        Integer expectedCount = 1;
        Integer actualCount = [SELECT COUNT() FROM Application__c];
        System.assertEquals(expectedCount, actualCount, 'Wrong custom setting count.');
        
        String expectedUrl = Page.Configure.getUrl() + '?stage=js';
        String actualUrl = redirect.getUrl();
        System.assertEquals(expectedUrl, actualUrl, 'Wrong redirect.');
        
        String expectedBase = Url.getSalesforceBaseUrl().toExternalForm().replace('http:', 'https:'); //#1188
        String actualBase = Application__c.getOrgDefaults().OrgBaseUrl__c;
        System.assertEquals(expectedBase, actualBase, 'Wrong base.');
        
        String expectedUnprefixedOrgId = UserInfo.getOrganizationId().substring(3, 15);
        String actualUnprefixedOrgId = Application__c.getOrgDefaults().OrgConfigured__c;
        System.assertEquals(expectedUnprefixedOrgId, actualUnprefixedOrgId, 'Wrong id.');
        
        String expectedReturnUrl = '/herp/derp';
        String actualReturnUrl = Application__c.getOrgDefaults().OrgReturnUrl__c;
        System.assertEquals(expectedReturnUrl, actualReturnUrl, 'Wrong return URL.');
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
        
        //arrange custom setting
        Application__c application = Application__c.getOrgDefaults();
        application.OrgReturnUrl__c = '/apex/test';
        upsert application;
        
        //act
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new TokenResponse());
        System.PageReference redirect = controller.doRedirect();
        Test.stopTest();
        
        //assert
        String expectedUrl = '/apex/';
        String actualUrl = redirect.getUrl();
        System.assert(actualUrl.startsWith(expectedUrl), 'Wrong URL.');
        
        Id expectedUserId = UserInfo.getUserId();
        Id actualUserId = Application__c.getOrgDefaults().RunAsUserId__c;
        System.assertEquals(expectedUserId, actualUserId, 'Wrong running user id.');
        
        String expectedRefreshToken = 'rrrrr';
        String actualRefreshToken = Application__c.getOrgDefaults().RunAsRefreshToken__c;
        System.assertEquals(expectedRefreshToken, actualRefreshToken, 'Wrong refresh token.');
    }
    
    static testmethod void testDoRedirectPostInstall() {
        //arrange controller and page
        ConfigureController controller = new ConfigureController();
        System.PageReference configure = Page.Configure;
        configure.getParameters().put('stage', 'pi');
        Test.setCurrentPage(configure);
        
        //act
        Test.startTest();
        PageReference redirect = controller.doRedirect();
        Test.stopTest();
        
        //assert
        Id expectedDebug = UserInfo.getUserId();
        Id actualDebug = DebugServiceConfig__c.getOrgDefaults().UserId__c;
        System.assertEquals(expectedDebug, actualDebug, 'Wrong debug user id.');
    }
    
    static testmethod void testDoRedirectStageCallBackIpRestricted() {
        //arrange controller and page
        ConfigureController controller = new ConfigureController();
        System.PageReference configure = Page.Configure;
        configure.getParameters().put('code', '12345'); //this implies stage=cb
        Test.setCurrentPage(configure);
        
        //act
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new IpRestrictedResponse());
        System.PageReference redirect = controller.doRedirect();
        Test.stopTest();
        
        //assert
        String expectedUrl = new System.PageReference('/packaging/installPackage.apexp?p0=04t24000000EkE2').getUrl();
        String actualUrl = redirect.getUrl();
        System.assertEquals(expectedUrl, actualUrl, 'Wrong URL.');
    }
    
    @TestVisible class UnauthorizedEndpointResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            CalloutException e = (CalloutException)CalloutException.class.newInstance();
            e.setMessage('Unauthorized endpoint, please check Setup->Security->Remote site settings.');
            throw e;
        }
    }
    
    @TestVisible class IpRestrictedResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setBody('{"error_description":"ip restricted","error":"invalid_grant"}');
            return response;
        }
    }
    
    @TestVisible class TokenResponse implements HttpCalloutMock {
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
    
    static testmethod void coverCode() {
        //arrange controller
        ConfigureController controller = new ConfigureController();
        
        //act
        controller.requestData();
        controller.javascript();
        
        //assert
        System.assert(!ApexPages.hasMessages(), 'Wrong messages.');
    }
    
    static testmethod void testConfigureIfNeeded() {
        //arrange
        PageReference retURL = new PageReference('/home/home.jsp');
        
        //act
        PageReference redirect = ConfigureController.ConfigureIfNeeded(retURL);
        
        //assert
        String expectedUrl = Page.Configure.getUrl();
        String actualUrl = redirect.getUrl();
        System.assert(actualUrl.containsIgnoreCase(expectedUrl), 'Wrong url.');
        System.assert(actualUrl.containsIgnoreCase('home.jsp'), 'Wrong retURL.');
        
        //act (pretend to configure)
        Application__c application = Application__c.getOrgDefaults();
        application.RunAsRefreshToken__c = '00D000000000000AAA';
        application.OrgConfigured__c = UserInfo.getOrganizationId().substring(3, 15);
        upsert application;
        
        //act
        redirect = ConfigureController.ConfigureIfNeeded(retURL);
        
        //assert
        System.assertEquals(null, redirect, 'Wrong url.');
    }
}