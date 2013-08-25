trigger PersistentDataAfterInsert on PersistentData__c (after insert) {

	//find all batch/scheduled jobs which have not finished
	List<AsyncApexJob> brokerJobs = [
		SELECT Id
		FROM AsyncApexJob
		WHERE ApexClass.Name = 'Broker'
		AND JobType IN ('BatchApex', 'ScheduledApex')
		AND Status IN ('Queued', 'Processing', 'Preparing')
	];
	
	if (!brokerJobs.isEmpty()) {
		//is running, stop here
		return;
	}
	
	List<AsyncApexJob> otherJobs = [
		SELECT Id
		FROM AsyncApexJob
		WHERE JobType IN ('BatchApex', 'ScheduledApex')
		AND Status IN ('Processing', 'Preparing')
	];
	
	if (otherJobs.size() < 5) {
		//slot available, run batch
		Database.executeBatch(new Broker(), 1);
	}
	
	/*else {
		//5 jobs already, schedule
		Datetime soon = System.now().addSeconds(60);
		String soonCron = soon.second() + ' ' + soon.minute() + ' ' + soon.hour() + ' ' + soon.day() + ' ' + soon.month() + ' ? ' + soon.year();
		else System.schedule('BatchBroker' + soon, soonCron, (System.Schedulable)new BatchBroker());
	}*/
}