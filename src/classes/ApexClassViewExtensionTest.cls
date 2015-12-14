@IsTest class ApexClassViewExtensionTest {

    @TestSetup static void testSetup() {
        //act
        new PostInstallHandler().onInstall(null);
        
        //assert
        System.assertNotEquals(null, Application__c.getOrgDefaults().Id, 'Wrong id.');
    }
    
    static testmethod void coverCode() {
        //arrange controller and extension
        ApexClass apexClass = [SELECT Id FROM ApexClass WHERE Name = 'TerminateService' AND NamespacePrefix = :Application__c.getOrgDefaults().Prefix__c];
        ApexPages.StandardController controller = new ApexPages.StandardController(apexClass);
        ApexClassViewExtension extension = new ApexClassViewExtension(controller);
        
        //act
        extension.doInit();
        
        //assert
        System.assert(!ApexPages.hasMessages(), 'Wrong messages.');
    }
    
}