global class Sink implements Process.Plugin {
	
	global Process.PluginDescribeResult describe() {
		return new Process.PluginDescribeResult();
	}
	
	global Process.PluginResult invoke(Process.PluginRequest request) {
		Map<String,Object> notification = request.inputParameters;
		
		//if we got here from a boomerang, back to where you came from!
		List<Map<String,Object>> notifications = new List<Map<String,Object>>();
		
		String boomerangChainStepId = (String)notification.get('eda__boomerangChainStepId');
		if (boomerangChainStepId != null) {
			ChainStep__c chainStep = [ 
				SELECT Id, Chain__r.Name, Sequence__c 
				FROM ChainStep__c 
				WHERE Id = :(Id)boomerangChainStepId
			];

			notification.remove('eda__boomerangChainStepId');
			notification.put('eda__chainName', chainStep.Chain__r.Name );
			notification.put('eda__sequence', chainStep.Sequence__c );
			notifications.add(notification);
 		}
		   
		return Utility.convert(notifications);
	}

}