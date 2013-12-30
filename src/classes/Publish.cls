public class Publish implements Process.Plugin {
	
	public class PublishException extends Exception {}
	
	public Process.PluginDescribeResult describe () {
		Process.PluginDescribeResult result = new Process.PluginDescribeResult();
		result.Description = 'Publishes to a named event {"eda__configurable": "'+Schema.SobjectType.PublishConfiguration__c.Name+'"}';
		return result;
	}
	
	public Process.PluginResult invoke(Process.PluginRequest request) {
		Map<String,Object> notification = request.InputParameters;
		List<Map<String,Object>> notifications = new List<Map<string,object>>();
		
		String chainName = (String)notification.get('eda__chainName');
		Decimal sequence = (Decimal)notification.get('eda__sequence');
		ChainStep__c chainStep = [
			SELECT Configuration__c
			FROM ChainStep__c
			WHERE Chain__r.Name = :chainName AND
			Sequence__c = :sequence
		];
		
		PublishConfiguration__c publishConfiguration = [
			SELECT Id, Event__c 
			FROM PublishConfiguration__c
			WHERE Id = :chainStep.Configuration__c
		];
		
		if (null == publishConfiguration.Event__c) {
			throw new PublishException('Publish Configuration ' + publishConfiguration.Id + ' has no Event');
		}
		
		Map<Id,SObject> subscribeConfigurations = new Map<Id,SObject>([
			SELECT Id 
			FROM SubscribeConfiguration__c
			WHERE Event__c = :publishConfiguration.Event__c
		]);
		
		List<ChainStep__c> steps = [
			SELECT Id, Chain__r.Name, Sequence__c
			FROM ChainStep__c
			WHERE Configuration__c IN :subscribeConfigurations.keySet()
		];
		
		for (ChainStep__c step : steps) {
			Map<String,Object> clone = notification.clone();
			clone.put('eda__sequence', step.Sequence__c);
			clone.put('eda__chainName', step.Chain__r.Name);
			notifications.add(clone);
		}
		
		//original guy carries on... this is not a sink
		notifications.add(notification);
		
		return Utility.convert(notifications);
	}
	
	
	
}