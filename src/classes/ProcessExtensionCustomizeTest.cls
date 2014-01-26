@isTest private class ProcessExtensionCustomizeTest {
    
    static testMethod void testCustomizableProcess() {
        //Arrange
        Process__c wiretapProcess = Processes.generateOne(Wiretap.class);
        ApexPages.StandardController controller = new ApexPages.StandardController(wiretapProcess);
        ProcessExtensionCustomize extension = new ProcessExtensionCustomize(controller);
        
        // Act
        //button should redirect to /[tab]/o (for a custom setting, this takes us to the manage screen)
        System.PageReference settingPage = extension.initCustom();

        // Assert
        System.assert(settingPage.getUrl().contains('/' + Schema.SObjectType.WiretapCustomization__c.KeyPrefix + '/o'));
    }

    static testMethod void testUncustomizableProcess() {
        //Arrange
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        ApexPages.StandardController controller = new ApexPages.StandardController(terminateProcess);
        ProcessExtensionCustomize extension = new ProcessExtensionCustomize(controller);
        
        // Act
        //button should redirect to /[process_id]  
        System.PageReference processPage = extension.initCustom();
        
        // Assert
        String expectedUrl = String.valueOf(terminateProcess.Id).left(15);
        String actualUrl = processPage.getUrl();
        System.assert(actualUrl.contains(expectedUrl));  
    }
    
}