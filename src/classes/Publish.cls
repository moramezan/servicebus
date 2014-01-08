public with sharing class Publish implements Process.Plugin, Database.Stateful {
	
	public class PublishException extends Exception {}
	
	public Process.PluginDescribeResult describe () {
		Process.PluginDescribeResult result = new Process.PluginDescribeResult();
		result.Description = 'Publishes to a named event {"eda__configurable": "'+Schema.SobjectType.PublishConfiguration__c.Name+'"}';
		result.Tag = 'Event Driven Architecture';
		return result;
	}
	
	public Process.PluginResult invoke(Process.PluginRequest request) {
		Map<String,Object> notification = request.InputParameters;
		List<Map<String,Object>> notifications = new List<Map<string,object>>();
		
		PublishConfiguration__c publishConfiguration = [
			SELECT Id, Event__c 
			FROM PublishConfiguration__c
			WHERE Id = :(Id)notification.get('eda__configuration')
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
			//#47: Any messages properties affecting the SINK behaviour should be stripped from FLOW CONTROL
			clone.put('eda__boomerangChainStepIds', null);
			clone.put('eda__sequence', step.Sequence__c);
			clone.put('eda__chainName', step.Chain__r.Name);
			notifications.add(clone);
		}
		
		//original guy carries on... this is not a sink
		notifications.add(notification);
		
		return Utility.convert(notifications);
	}
	
	
	
}