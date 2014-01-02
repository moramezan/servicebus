trigger PersistentDataAfterUpdate on PersistentData__c (after update) {
	
	Id bufferId = SObjectType.PersistentData__c.RecordTypeInfosByName.get('Buffer').RecordTypeId;
	Id reprocessId = SObjectType.PersistentData__c.RecordTypeInfosByName.get('Reprocess').RecordTypeId;
	Id processingId = SObjectType.PersistentData__c.RecordTypeInfosByName.get('Processing').RecordTypeId;
	
	Boolean processing2bufferOrReprocess = false;
	
	for (PersistentData__c oldData : Trigger.old) {
		PersistentData__c newData = Trigger.newMap.get(oldData.Id);
		if (
			oldData.RecordTypeId == processingId && newData.RecordTypeId == bufferId
			||
			oldData.RecordTypeId == processingId && newData.RecordTypeId == reprocessId
			||
			oldData.RecordTypeId == bufferId && newData.RecordTypeId == reprocessId
		) {
			//if any persistent data changed from 'Processing' to 'Buffer',    let's start the munger
			//if any persistent data changed from 'Processing' to 'Reprocess', let's start the munger
			//if any persistent data changed from 'Buffer'     to 'Reprocess', let's start the munger
			processing2bufferOrReprocess = true;
			break;
		}
	}
	
	if (processing2bufferOrReprocess) Database.executeBatch(new Broker(), 1);
	
}