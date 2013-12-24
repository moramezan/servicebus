public class ProcessExtensionRefresh {
	
	public ProcessExtensionRefresh(ApexPages.StandardSetController controller) {
		//
	}
	
	public System.PageReference doRedirect() {
		String prefix = Process__c.getSObjectType().getDescribe().getKeyPrefix();
		System.PageReference tab = new System.PageReference('/' + prefix);
		
		//find all batch/scheduled jobs which have not finished
		List<AsyncApexJob> refreshJobs = [
			SELECT Id
			FROM AsyncApexJob
			WHERE ApexClass.Name = 'ProcessRefreshBatch'
			AND JobType IN ('BatchApex', 'ScheduledApex')
			AND Status IN ('Queued', 'Processing', 'Preparing')
		];
		
		if (!refreshJobs.isEmpty()) {
			//is running, stop here
			return tab;
		}
		
		List<AsyncApexJob> otherJobs = [
			SELECT Id
			FROM AsyncApexJob
			WHERE JobType IN ('BatchApex', 'ScheduledApex')
			AND Status IN ('Processing', 'Preparing')
		];
		
		if (otherJobs.size() < 5) {
			//slot available, run batch
			Database.executeBatch(new ProcessRefreshBatch(), 1);
		}
		
		return tab;
	}
	
}