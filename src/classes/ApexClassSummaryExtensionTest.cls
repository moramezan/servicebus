@IsTest class ApexClassSummaryExtensionTest {
    
    static testmethod void coverCode() {
        //arrange controller and extension
        ApexClass apexClass = [SELECT Id FROM ApexClass WHERE Name = 'Terminate' AND NamespacePrefix = :NamespaceSetting__c.getOrgDefaults().Prefix__c];
        ApexPages.StandardController controller = new ApexPages.StandardController(apexClass);
        ApexClassSummaryExtension extension = new ApexClassSummaryExtension(controller);
        
        //act
        extension.doInit();
        
        //assert
        System.assert(!ApexPages.hasMessages(), 'Wrong messages.');
    }
    
}