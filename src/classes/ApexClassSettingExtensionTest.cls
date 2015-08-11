@IsTest public class ApexClassSettingExtensionTest {

    static testmethod void coverCode() {
        //arrange
        ApexClass apexClass = [SELECT Id FROM ApexClass WHERE Name = :ApexClassHelpExtensionTest.class.getName()];
        
        //act
        ApexPages.StandardController controller = new ApexPages.StandardController(apexClass);
        ApexClassSettingExtension extension = new ApexClassSettingExtension(controller);
        extension.doRedirect();
        
        //assert
        System.assert(ApexPages.hasMessages(), 'Wrong messages.');
    }

}