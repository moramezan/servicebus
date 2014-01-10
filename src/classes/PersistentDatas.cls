public class PersistentDatas extends SObjects {
	
	override public void onAfterInsert(Map<Id,SObject> objects) {
		this.startBatchIfAppropriate(objects);
	}
	
	override public void onAfterUpdate(Map<Id,SObject> olds, Map<Id,SObject> news) {
		Id bufferId = SObjectType.PersistentData__c.RecordTypeInfosByName.get('Buffer').RecordTypeId;
		Id reprocessId = SObjectType.PersistentData__c.RecordTypeInfosByName.get('Reprocess').RecordTypeId;
		Id processingId = SObjectType.PersistentData__c.RecordTypeInfosByName.get('Processing').RecordTypeId;

		Boolean processing2bufferOrReprocess = false;
		
		for (PersistentData__c oldData : (List<PersistentData__c>)olds.values()) {
			PersistentData__c newData = ((Map<Id,PersistentData__c>)news).get(oldData.Id);
			if (
				oldData.RecordTypeId == processingId && newData.RecordTypeId == bufferId
				||
				oldData.RecordTypeId == processingId && newData.RecordTypeId == reprocessId
				||
				oldData.RecordTypeId == bufferId && newData.RecordTypeId == reprocessId
			) {
				//if any persistent data changed from 'Processing' to 'Buffer',	let's start the munger
				//if any persistent data changed from 'Processing' to 'Reprocess', let's start the munger
				//if any persistent data changed from 'Buffer'	 to 'Reprocess', let's start the munger
				processing2bufferOrReprocess = true;
				break;
			}
		}

		if (processing2bufferOrReprocess) Database.executeBatch(new Broker(), 1);
	}
	
	@testVisible private void startBatchIfAppropriate(Map<Id,SObject> objects) {
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
	
}