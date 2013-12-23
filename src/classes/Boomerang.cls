global class Boomerang implements Processable, Configurable {
	
	global SObject configure() {
		return new BoomerangConfiguration__c();
	}
	
	global List<Map<String,Object>> execute(Map<String,Object> notification) {
		//get destination from configuration
		BoomerangConfiguration__c configuration = [
			SELECT Id, Chain__r.Name
			FROM BoomerangConfiguration__c
			WHERE Id = :(Id)notification.get('eda__configuration')
		];
		
		notification.put('eda__boomerangChainName', notification.get('eda__chainName'));
		notification.put('eda__boomerangSequence', notification.get('eda__sequence'));
		notification.put('eda__chainName', configuration.Chain__r.Name);
		notification.put('eda__sequence', 0);
		
		return new List<Map<String,Object>>{notification};
	}
	
}