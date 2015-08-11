@IsTest public class ApexClassHelpExtensionTest {
    
    static testmethod void coverCode() {
        //arrange controller and extension
        ApexClass apexClass = [SELECT Id FROM ApexClass WHERE Name = :ApexClassHelpExtensionTest.class.getName()];
        ApexPages.StandardController controller = new ApexPages.StandardController(apexClass);
        ApexClassHelpExtension extension = new ApexClassHelpExtension(controller);
        
        //act
        extension.doInit();
        
        //assert
        System.assert(ApexPages.hasMessages(), 'Wrong messages.');
    }
    
}