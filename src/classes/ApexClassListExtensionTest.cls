@IsTest class ApexClassListExtensionTest {
    
    @TestSetup static void testSetup() {
        //act
        new PostInstallHandler().upsertNamespaceSetting();
        ApexClassSetModel.saveCache(ApexClassSetModel.fromNamespace(NamespaceSetting__c.getOrgDefaults().Prefix__c).discoverSummaries());
        
        //assert
        System.assertNotEquals(null, NamespaceSetting__c.getOrgDefaults().Id, 'Wrong id.');
        System.assert(!ApexClassSetModel.loadCache().isEmpty(), 'Wrong id.');
    }
    
    static testmethod void testDoRedirect() {
        //act
        PageReference redirect = new ApexClassListExtension().doRedirect();
        
        //assert
        System.assertNotEquals(null, redirect, 'Wrong redirect.');
        
        //act (pretend to configure)
        OAuthSetting__c oauthSetting = OAuthSetting__c.getOrgDefaults();
        oauthSetting.AccessToken__c = '00D000000000000AAA';
        oauthSetting.UnprefixedOrgId__c = UserInfo.getOrganizationId().substring(3, 15);
        upsert oauthSetting;
        
        //act (pretend to discover)
        BrokerSetting__c brokerSetting = BrokerSetting__c.getOrgDefaults();
        brokerSetting.CacheKey__c = ApexClassSetModel.classKey();
        upsert brokerSetting;
        
        //act
        redirect = new ApexClassListExtension().doRedirect();
        
        //assert
        System.assertEquals(null, redirect, 'Wrong redirect.');
    }
    
}