@IsTest public class ApexClassSummaryExtensionTest {
    
    static testmethod void coverCode() {
        //arrange controller and extension
        ApexClass apexClass = [SELECT Id FROM ApexClass WHERE Name = :ApexClassSummaryExtensionTest.class.getName()];
        ApexPages.StandardController controller = new ApexPages.StandardController(apexClass);
        ApexClassSummaryExtension extension = new ApexClassSummaryExtension(controller);
        
        //act
        extension.doInit();
        
        //assert
        System.assert(!ApexPages.hasMessages(), 'Wrong messages.');
    }
    
}