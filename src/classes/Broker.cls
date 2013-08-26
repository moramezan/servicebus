public class Broker implements Database.Batchable<SObject>, Database.AllowsCallouts {

	public Database.QueryLocator start(Database.BatchableContext context) {
		//find some buffered work
		Map<Id, PersistentData__c> id2data = new Map<Id, PersistentData__c>([
			SELECT Id
			FROM PersistentData__c
			WHERE RecordType.Name = 'Buffer'
			LIMIT 1000
		]);
		
		//get processing record type
		String processingId = SObjectType.PersistentData__c.RecordTypeInfosByName.get('Processing').RecordTypeId;
		
		for (PersistentData__c persistentData : id2data.values()) {
			persistentData.RecordTypeId = processingId;
		}
		
		//mark them as processing
		update id2data.values();
		
		//get those exact same list of ids
		Set<Id> ids = id2data.keySet();
		
		//as a comma delimited string
		String ins = '(\'' + String.join(new List<Id>(ids), '\',\'') + '\')';
		
		//hand back just the ones we have marked (WHERE AGE < APEX TIMEOUT ETC)
		return Database.getQueryLocator('SELECT Id, Notification__c FROM PersistentData__c WHERE Id IN ' + ins);
	}
	
	public void execute(Database.BatchableContext context, List<SObject> scope) {
		//list of one
		PersistentData__c persistentData = (PersistentData__c)scope[0];
		
		//prepare the notification (a primitive dto) from persistent data
		Map<String,Object> notification = (Map<String,Object>)Json.deserializeUntyped(persistentData.Notification__c);
		
		//increment sequence
		notification.put('sequence', (Decimal)notification.get('sequence') + 1);
		
		//resolve chain step
		ChainStep__c chainStep = [
			SELECT Process__c, Configuration__c
			FROM ChainStep__c
			WHERE Chain__r.Name = :(String)notification.get('chainName')
			AND Sequence__c = :(Decimal)notification.get('sequence')
		];
		
		//resolve processable
		Process__c process = [
			SELECT Id, ApexClass__c
			FROM Process__c
			WHERE Id = :chainStep.Process__c
		];
		
		//instantiate processable instance
		Type reflector = Type.forName(process.ApexClass__c);
		Processable processable = (Processable)reflector.newInstance();
		
		//hand in the configuration id
		notification.put('configuration', chainStep.Configuration__c);
		
		//invoke the processable instance
		List<Map<String,Object>> notifications = processable.execute(notification);
		
		//count the notifications if marked
		Decimal markCount = (Decimal)notification.get('markCount');
		
		//increment markCount THEN put that value on notification
		if (null != markCount) notification.put('markCount', ++markCount);
		
		//the above process would have been a splitter
		if (2 == markCount) {
			Integer count = notifications.size();
			notification.put('count', count);
			if (count == 0) Database.delete(new List<Id>{(Id)notification.get('gateGroupId')}); //tidy up split of 0
		}
		
		//get buffer record type
		String bufferId = SObjectType.PersistentData__c.RecordTypeInfosByName.get('Buffer').RecordTypeId;
		
		//prepare the Persistent Data buffer for future processing
		List<PersistentData__c> persistentDatas = new List<PersistentData__c>();
		for (Map<String,Object> n : notifications) {
			persistentDatas.add(new PersistentData__c(
				Notification__c = Json.serialize(n),
				RecordTypeId = bufferId
			));
		}
		
		//tidy up the successfully processed notification
		delete persistentData;
		
		//persist these notifications to be picked up in the next batch run
		insert persistentDatas;
	}
	
	public void finish(Database.BatchableContext context) {
		List<PersistentData__c> persistentDatas = [
			SELECT Id
			FROM PersistentData__c
			WHERE RecordType.Name = 'Buffer'
		];
		
		if (!persistentDatas.isEmpty()) {
			//new stuff to do
			Database.executeBatch(new Broker(), 1);
		}
	}
	
	static public void enqueue(String chainName, Id data) {
		//scaffold the notification, pointing to the stored data
		Map<String,Object> notification = new Map<String,Object>{
			'chainName' => chainName,
			'sequence' => 0,
			'id' => data
		};
		
		//enqueue the notification onto the buffer
		insert new PersistentData__c(
			RecordTypeId = SObjectType.PersistentData__c.RecordTypeInfosByName.get('Buffer').RecordTypeId,
			Notification__c = Json.serialize(notification)
		);
	}
	
	static public void enqueue(String chainName, Blob data) {
		//prepare a very generic container
		Document document = new Document(
			Name = String.valueOf(Datetime.now().getTime()),
			Body = data,
			FolderId = [SELECT Id FROM Folder WHERE Name = 'Eda'].Id,
			ContentType = 'text/plain',
			Type = 'txt'
		);
		
		//store this data away and enqueue
		insert document;
		enqueue(chainName, document.Id);
	}
	
}