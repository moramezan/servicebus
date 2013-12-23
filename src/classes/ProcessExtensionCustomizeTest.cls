@isTest public class ProcessExtensionCustomizeTest {
	
	public class CustomizableProcess implements Customizable {
		public SObjectType customize() {
			return Account.SObjectType;
		}
	}
	
	static testMethod void testCustomizableProcess() {
		Process__c process = new Process__c(ApexClass__c = 'ProcessExtensionCustomizeTest.CustomizableProcess');
		ApexPages.StandardController controller = new ApexPages.StandardController(process);
		ProcessExtensionCustomize extension = new ProcessExtensionCustomize(controller);
		
		//button should redirect to /[tab]/o (for a custom setting, this takes us to the manage screen)
		System.PageReference settingPage = extension.initCustom();
		System.assert(settingPage.getUrl().contains('/001/o'));
	}
	
	public class UncustomizableProcess {
		//
	}
	
	static testMethod void testUncustomizableProcess() {
		Process__c process = new Process__c(ApexClass__c = 'ProcessExtensionCustomizeTest.UncustomizableProcess');
		ApexPages.StandardController controller = new ApexPages.StandardController(process);
		ProcessExtensionCustomize extension = new ProcessExtensionCustomize(controller);
		
		//button should redirect to /[process_id] (will be null during test as process was never inserted)
		System.PageReference processPage = extension.initCustom();
		System.assertEquals(null, processPage.getUrl());
	}
	
}