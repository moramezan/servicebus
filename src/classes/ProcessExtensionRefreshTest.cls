@isTest public class ProcessExtensionRefreshTest {
	
	static testMethod void testStartRefreshJob() {
		//normal case where there are slots available and the job is not running
		List<Process__c> processes = new List<Process__c>();
		ApexPages.StandardSetController controller = new ApexPages.StandardSetController(processes);
		ProcessExtensionRefresh extension = new ProcessExtensionRefresh(controller);
		
		Test.startTest();
		System.PageReference tab = extension.doRedirect();
		Test.stopTest();
		
		System.assert(tab.getUrl().contains('running=ok'));
	}
	
	static testMethod void testNotEnoughSlots() {
		//there are already 5 batches running
		List<Process__c> processes = new List<Process__c>();
		ApexPages.StandardSetController controller = new ApexPages.StandardSetController(processes);
		ProcessExtensionRefresh extension = new ProcessExtensionRefresh(controller);
		
		extension.otherJobs = new List<AsyncApexJob>{
			new AsyncApexJob(),
			new AsyncApexJob(),
			new AsyncApexJob(),
			new AsyncApexJob(),
			new AsyncApexJob()
		};
		
		System.PageReference tab = extension.doRedirect();
		System.assert(tab.getUrl().contains('error=insufficient_slots'));
	}
	
	static testMethod void testAlreadyRunning() {
		//the refresh batch is already running
		List<Process__c> processes = new List<Process__c>();
		ApexPages.StandardSetController controller = new ApexPages.StandardSetController(processes);
		ProcessExtensionRefresh extension = new ProcessExtensionRefresh(controller);
		
		extension.refreshJobs = new List<AsyncApexJob>{
			new AsyncApexJob()
		};
		
		System.PageReference tab = extension.doRedirect();
		System.assert(tab.getUrl().contains('error=already_running'));
	}

}