global class Gate implements Processable {

	global List<Map<String,Object>> execute(Map<String,Object> notification) {
		Id gateGroupId = (Id)notification.get('gateGroupId');
		Decimal count = (Decimal)notification.get('count');
		
		insert new GateItem__c(
			GateGroup__c = gateGroupId,
			Notification__c = Json.serialize(notification)
		);
		
		List<GateItem__c> gateItems = [
			SELECT Id
			FROM GateItem__c
			WHERE GateGroup__c = :gateGroupId
		];
		
		if (count != gateItems.size()) {
			//this is not the last item, so let's swallow
			return new List<Map<String,Object>>();
		}	
		
		//this is the last item, let's release
		notification.put('id', gateGroupId);
		
		return new List<Map<String,Object>>{notification};
	}
	
}