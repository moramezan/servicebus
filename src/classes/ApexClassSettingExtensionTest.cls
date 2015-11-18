@IsTest class ApexClassSettingExtensionTest {

    @TestSetup static void testSetup() {
        //act
        new PostInstallHandler().upsertNamespaceSetting();
        
        //assert
        System.assertNotEquals(null, NamespaceSetting__c.getOrgDefaults().Id, 'Wrong id.');
    }
    
    static testmethod void coverCode() {
        //arrange
        ApexClass apexClass = [
            SELECT Id
            FROM ApexClass
            WHERE Name = 'Wiretap'
            AND NamespacePrefix = :NamespaceSetting__c.getOrgDefaults().Prefix__c
        ];
        
        //act
        Test.setCurrentPage(Page.ApexClassSetting);
        ApexPages.StandardController controller = new ApexPages.StandardController(apexClass);
        ApexClassSettingExtension extension = new ApexClassSettingExtension(controller);
        
        //assert
        System.assert(!ApexPages.hasMessages(), 'Wrong messages.');
    }

}