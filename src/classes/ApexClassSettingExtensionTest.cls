@IsTest public class ApexClassSettingExtensionTest {

    static testmethod void coverCode() {
        //arrange
        ApexClass apexClass = [SELECT Id FROM ApexClass WHERE Name = :ApexClassSettingExtensionTest.class.getName()];
        
        //act
        ApexPages.StandardController controller = new ApexPages.StandardController(apexClass);
        ApexClassSettingExtension extension = new ApexClassSettingExtension(controller);
        extension.showSetting();
        
        //assert
        System.assert(ApexPages.hasMessages(), 'Wrong messages.');
    }

}