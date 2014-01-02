public class Broker implements Database.Batchable<SObject>, Database.AllowsCallouts {

	public class BrokerException extends Exception {}

	public Database.QueryLocator start(Database.BatchableContext context) {
		Integer fuckedLimit = 100;
		
		Integer fuckedCount = [
			SELECT COUNT()
			FROM PersistentData__c
			WHERE RecordType.Name = 'Processing'
		];
		
		Integer reprocessCount = [
			SELECT COUNT()
			FROM PersistentData__c
			WHERE RecordType.Name = 'Reprocess'
		];
		
		Integer queryLimit = Math.max(0, fuckedLimit - fuckedCount) + reprocessCount;
		
		if (queryLimit == 0) {
			System.abortJob(context.getJobId());
		}
		
		//find some Buffer work, or if there's too many in Processing, only find Reprocess work
		Map<Id, PersistentData__c> id2data = new Map<Id, PersistentData__c>([
			SELECT Id
			FROM PersistentData__c
			WHERE RecordType.Name IN ('Reprocess', 'Buffer')
			ORDER BY RecordType.Name DESC
			LIMIT :queryLimit
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

		//keep scope outside exception
		Map<String,Object> notification;
		List<Map<String,Object>> notifications = new List<Map<String,Object>>();

		try {
			//prepare the notification (a primitive dto) from persistent data
			notification = (Map<String,Object>)Json.deserializeUntyped(persistentData.Notification__c);

			//increment sequence
			notification.put('eda__sequence', (Decimal)notification.get('eda__sequence') + 1);

			//resolve chain step
			ChainStep__c chainStep = [
				SELECT Process__c, Configuration__c
				FROM ChainStep__c
				WHERE Chain__r.Name = :(String)notification.get('eda__chainName')
				AND Sequence__c = :(Decimal)notification.get('eda__sequence')
			];

			//resolve processable
			Process__c process = [
				SELECT Id, Name
				FROM Process__c
				WHERE Id = :chainStep.Process__c
			];

			//instantiate processable instance
			Type reflector = Type.forName(process.Name);
			Process.Plugin processable = (Process.Plugin)reflector.newInstance();

			//hand in the configuration id
			notification.put('eda__configuration', chainStep.Configuration__c);

			//invoke the processable instance
			Process.PluginResult results = processable.invoke(new Process.PluginRequest(notification));
			notifications = Utility.convert(results);
		} catch (Exception e) {
			if (e instanceof System.JsonException) {
				e.setMessage('Could not deserialize json (malformed notification)');
			} else if (e instanceof System.NullPointerException) {
				e.setMessage('Sequence null (key missing from notification) or Type null (class missing)');
			} else if (e instanceof System.QueryException) {
				e.setMessage('ChainStep unqueryable (bad chain name, sequence, missing sink)');
			} else if (e instanceof System.TypeException) {
				e.setMessage('Could not cast Process.Plugin (interface unimplemented on process class)');
			}
			Map<String,Object> serializedException = new Map<String,Object>();
			serializedException.put('cause', e.getCause());
			serializedException.put('lineNumber', e.getLineNumber());
			serializedException.put('message', e.getMessage());
			serializedException.put('stackTraceString', e.getStackTraceString());
			serializedException.put('typeName', e.getTypeName());
			
			//log any exceptions
			persistentData.Message__c = e.getMessage().left(255);
			update persistentData;
			
			//including any big ones
			insert new Note(
				ParentId = persistentData.Id,
				Title = e.getMessage().left(255),
				Body = System.Json.serializePretty(serializedException)
			);
			
			//get out of dodge quick
			return;
		}
		
		//count the notifications if marked
		Decimal markCount = (Decimal)notification.get('eda__markCount');
		
		//increment markCount THEN put that value on notification
		if (null != markCount) notification.put('eda__markCount', ++markCount);
		
		//the above process would have been a splitter
		if (2 == markCount) {
			Integer count = notifications.size();
			notification.put('eda__count', count);
			if (count == 0) Database.delete(new List<Id>{(Id)notification.get('eda__gateGroupId')}); //tidy up split of 0
		}
		
		//get buffer record type
		String bufferId = SObjectType.PersistentData__c.RecordTypeInfosByName.get('Buffer').RecordTypeId;
		
		//prepare the Persistent Data buffer for future processing
		List<PersistentData__c> persistentDatas = new List<PersistentData__c>();
		for (Map<String,Object> n : notifications) {
			persistentDatas.add(new PersistentData__c(
				Notification__c = Json.serializePretty(n),
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

		// empty recycle to remove form recents
		List<PersistentData__c> pds = [SELECT Id FROM PersistentData__c WHERE IsDeleted = true ALL ROWS];
		Database.emptyRecycleBin(pds);
	}
	
	static public void enqueue(String chainName, Id data) {
		//scaffold the notification, pointing to the stored data
		Map<String,Object> notification = new Map<String,Object>{
			'eda__chainName' => chainName,
			'eda__sequence' => 0,
			'id' => data
		};
		
		//enqueue the notification onto the buffer
		insert new PersistentData__c(
			RecordTypeId = SObjectType.PersistentData__c.RecordTypeInfosByName.get('Buffer').RecordTypeId,
			Notification__c = Json.serializePretty(notification)
		);
	}
	
	static public void enqueue(String chainName, Blob data) {
		//prepare a very generic container
		Document document = new Document(
			Name = String.valueOf(Datetime.now().getTime()),
			Body = data,
			FolderId = UserInfo.getUserId(),
			ContentType = 'text/plain',
			Type = 'txt'
		);
		
		//store this data away and enqueue
		insert document;
		enqueue(chainName, document.Id);
	}
	
}