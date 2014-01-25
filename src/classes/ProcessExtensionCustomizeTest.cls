@isTest private class ProcessExtensionCustomizeTest {
    
    static testMethod void testCustomizableProcess() {
        //Arrange
        String  className  = 'Wiretap';
        List<String> names = new List<String>{className};
        List<ApexClass> objects = [SELECT NamespacePrefix, Name FROM ApexClass WHERE Name IN :Names];
        ApexClasses apexClasses = new ApexClasses(objects);
        List<Process__c> processes = apexClasses.regenerate();
        ApexPages.StandardController controller = new ApexPages.StandardController(processes[0]);
        ProcessExtensionCustomize extension = new ProcessExtensionCustomize(controller);
        
        // Act
        //button should redirect to /[tab]/o (for a custom setting, this takes us to the manage screen)
        System.PageReference settingPage = extension.initCustom();

        // Assert
        System.assert(settingPage.getUrl().contains('/' + Schema.SObjectType.WiretapCustomization__c.KeyPrefix + '/o'));
    }

    static testMethod void testUncustomizableProcess() {
        //Arrange
        String  className  = 'Terminate';
        List<String> names = new List<String>{className};
        List<ApexClass> objects = [SELECT NamespacePrefix, Name FROM ApexClass WHERE Name IN :Names];
        ApexClasses apexClasses = new ApexClasses(objects);
        List<Process__c> processes = apexClasses.regenerate();
        ApexPages.StandardController controller = new ApexPages.StandardController(processes[0]);
        ProcessExtensionCustomize extension = new ProcessExtensionCustomize(controller);
        
        // Act
        //button should redirect to /[process_id]  
        System.PageReference processPage = extension.initCustom();
        
        // Assert
        System.assertEquals(null, processPage.getUrl());  
    }
    
}