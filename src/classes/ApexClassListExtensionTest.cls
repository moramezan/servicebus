@IsTest class ApexClassListExtensionTest {
    
    @TestSetup static void testSetup() {
        //act
        new PostInstallHandler().upsertApplication();
        ApexClassSetModel.saveCache(ApexClassSetModel.fromNamespace(Application__c.getOrgDefaults().Prefix__c).discoverSummaries());
        
        //assert
        System.assertNotEquals(null, Application__c.getOrgDefaults().Id, 'Wrong id.');
        System.assert(!ApexClassSetModel.loadCache().isEmpty(), 'Wrong id.');
    }
    
    static testmethod void testDoRedirect() {
        //act
        PageReference redirect = new ApexClassListExtension().doRedirect();
        
        //assert
        System.assertNotEquals(null, redirect, 'Wrong redirect.');
        
        //act (pretend to configure)
        Application__c application = Application__c.getOrgDefaults();
        application.RunAsAccessToken__c = '00D000000000000AAA';
        application.OrgIdConfigured__c = UserInfo.getOrganizationId().substring(3, 15);
        upsert application;
        
        //act (pretend to discover)
        ApexClassSetModel.saveCache(ApexClassSetModel.fromNamespace(Application__c.getOrgDefaults().Prefix__c).discoverSummaries());
        
        //act
        redirect = new ApexClassListExtension().doRedirect();
        
        //assert
        System.assertEquals(null, redirect, 'Wrong redirect.');
    }
    
}