@IsTest class ApexClassConfigExtensionTest {

    @TestSetup static void testSetup() {
        //act
        new PostInstallHandler().onInstall(null);
        
        //assert
        System.assertNotEquals(null, Application__c.getOrgDefaults().Id, 'Wrong id.');
    }
    
    static testmethod void coverCode() {
        //arrange
        ApexClass apexClass = [
            SELECT Id
            FROM ApexClass
            WHERE Name = 'WiretapService'
            AND NamespacePrefix = :Application__c.getOrgDefaults().Prefix__c
        ];
        
        //act
        Test.setCurrentPage(Page.ApexClassConfig);
        ApexPages.StandardController controller = new ApexPages.StandardController(apexClass);
        ApexClassConfigExtension extension = new ApexClassConfigExtension(controller);
        
        //assert
        System.assert(!ApexPages.hasMessages(), 'Wrong messages.');
    }

}