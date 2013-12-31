global class Sink implements Process.Plugin {
	
	global Process.PluginDescribeResult describe() {
		return new Process.PluginDescribeResult();
	}
	
	global Process.PluginResult invoke(Process.PluginRequest request) {
		Map<String,Object> notification = request.inputParameters;
		
		//if we got here from a boomerang, back to where you came from!
		List<Map<String,Object>> notifications = new List<Map<String,Object>>();
		Object data = notification.get('eda__boomerangChainStepIds');
		
		if (data == null) {
			//no boomerangs
			return Utility.convert(notifications);
		}

		List<Id> chainStepIds = (List<Id>)System.Json.deserialize(System.Json.serialize(data), List<Id>.class);
		if (chainStepIds.isEmpty()) {
			//boomerangs finished
			return Utility.convert(notifications);
		}
		
		//pop one boomerang off stack
		Id lastId = chainStepIds.remove(chainStepIds.size() - 1);
		ChainStep__c chainStep = [ 
			SELECT Id, Chain__r.Name, Sequence__c 
			FROM ChainStep__c 
			WHERE Id = :lastId
		];
		
		notification.put('eda__boomerangChainStepIds', chainStepIds);
		notification.put('eda__chainName', chainStep.Chain__r.Name );
		notification.put('eda__sequence', chainStep.Sequence__c );
		notifications.add(notification);

		return Utility.convert(notifications);
	}

}