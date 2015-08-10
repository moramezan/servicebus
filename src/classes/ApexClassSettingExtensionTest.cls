@IsTest public class ApexClassSettingExtensionTest {

    static testmethod void coverCode() {
        //arrange record
        ApexClass apexClass = [
            SELECT Id
            FROM ApexClass
            WHERE NamespacePrefix = :NamespaceSetting__c.getOrgDefaults().Prefix__c
            AND Name = 'Wiretap'
        ];
        
        //act
        ApexPages.StandardController controller = new ApexPages.StandardController(apexClass);
        ApexClassSettingExtension extension = new ApexClassSettingExtension(controller);
        PageReference redirect = extension.doRedirect();
        
        //assert
        System.assert(!ApexPages.hasMessages(), 'Wrong messages.');
    }

}