trigger PersistentDataAfterUpdate on PersistentData__c (after update) {
	
	Id bufferId = SObjectType.PersistentData__c.RecordTypeInfosByName.get('Buffer').RecordTypeId;
	Id processingId = SObjectType.PersistentData__c.RecordTypeInfosByName.get('Processing').RecordTypeId;
	
	Boolean processing2buffer = false;
	
	for (PersistentData__c oldData : Trigger.old) {
		PersistentData__c newData = Trigger.newMap.get(oldData.Id);
		if (processingId == oldData.RecordTypeId && bufferId == newData.RecordTypeId) {
			//if any persistent data changed from 'Processing' to 'Buffer', let's start the munger
			processing2buffer = true;
			break;
		}
	}
	
	if (processing2buffer) Database.executeBatch(new Broker(), 1);
	
}