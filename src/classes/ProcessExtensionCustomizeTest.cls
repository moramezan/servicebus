@isTest public class ProcessExtensionCustomizeTest {
    
    public class CustomizableProcess implements Process.Plugin {
        
        public Process.PluginDescribeResult describe() {
            Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
            plugin.Description = '{"eda__customizable":"' + Schema.SObjectType.BranchConfiguration__c.Name + '"}';
            return plugin;
        }
        
        public Process.PluginResult invoke(Process.PluginRequest request) {
            return new Process.PluginResult(new Map<String,Object>());
        }
    }
    
    static testMethod void testCustomizableProcess() {
        Process__c process = new Process__c(Name = 'Wiretap');
        insert process;
        ApexPages.StandardController controller = new ApexPages.StandardController(process);
        ProcessExtensionCustomize extension = new ProcessExtensionCustomize(controller);
        
        //button should redirect to /[tab]/o (for a custom setting, this takes us to the manage screen)
        System.PageReference settingPage = extension.initCustom();
        System.assert(settingPage.getUrl().contains('/' + Schema.SObjectType.WiretapCustomization__c.KeyPrefix + '/o'));
    }
    
    public class UncustomizableProcess {
        //
    }
    
    static testMethod void testUncustomizableProcess() {
        Process__c process = new Process__c(Name = 'ProcessExtensionCustomizeTest.UncustomizableProcess');
        ApexPages.StandardController controller = new ApexPages.StandardController(process);
        ProcessExtensionCustomize extension = new ProcessExtensionCustomize(controller);
        
        //button should redirect to /[process_id] (will be null during test as process was never inserted)
        System.PageReference processPage = extension.initCustom();
        System.assertEquals(null, processPage.getUrl());
    }
    
}