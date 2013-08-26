global class Boomerang implements Processable, Configurable {
	
    global SObject configure() {
        return new BoomerangConfiguration__c();
    }
    
    global List<Map<String,Object>> execute(Map<String,Object> notification) {
        //get destination from configuration
        BoomerangConfiguration__c configuration = [
            SELECT Id, Chain__r.Name
            FROM BoomerangConfiguration__c
            WHERE Id = :(Id)notification.get('configuration')
        ];
        
        notification.put('boomerangChainName', notification.get('chainName'));
        notification.put('boomerangSequence', notification.get('sequence'));
        notification.put('chainName', configuration.Chain__r.Name);
        notification.put('sequence', 0);
        
        return new List<Map<String,Object>>{notification};
    }
    
}