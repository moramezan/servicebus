@IsTest class ApexClassListExtensionTest {
    
    @TestSetup static void testSetup() {
        //act
        new PostInstallHandler().onInstall(null);
        
        //assert
        System.assertNotEquals(null, Application__c.getOrgDefaults().Id, 'Wrong id.');
    }
    
    static testmethod void testDoRedirect() {
        //act
        PageReference redirect = new ApexClassListExtension().doRedirect();
        
        //assert
        System.assertNotEquals(null, redirect, 'Wrong redirect.');
        
        //act (pretend to discover)
        ApexClassSetModel.saveCache(ApexClassSetModel.fromNamespace(Application__c.getOrgDefaults().Prefix__c).discoverDefinitions());
        
        //act
        redirect = new ApexClassListExtension().doRedirect();
        
        //assert
        System.assertEquals(null, redirect, 'Wrong redirect.');
    }
    
}