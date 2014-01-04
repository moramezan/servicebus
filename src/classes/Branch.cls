global class Branch implements Process.Plugin {
	
	public class BranchException extends Exception {}
	
	global Process.PluginDescribeResult describe() {
		Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
		plugin.Description = 'This process forks execution. {"eda__configurable":"BranchConfiguration__c"}';
        plugin.Tag = 'Event Driven Architecture';
		return plugin;
	}
	
	global Process.PluginResult invoke(Process.PluginRequest request) {
		Map<String,Object> notification = request.inputParameters;
		
		//get step configuration
		BranchConfiguration__c configuration = [
			SELECT Id, Chain__r.Name
			FROM BranchConfiguration__c
			WHERE Id = :(Id)notification.get('eda__configuration')
		];
		
		//get chain name
		String branchTo = configuration.Chain__r.Name;
		
		//prevent recursion
		if (branchTo == (String)notification.get('eda__chainName')) {
			throw new BranchException('Not allowed to branch to own chain!');
		}
		
		//careful: by returning 2 notification, the broker may think the process was a splitter
		Map<String,Object> clone = notification.clone();
		clone.put('eda__chainName', branchTo);
		clone.put('eda__sequence', 0);
		
		//TODO
		//we might have an inbound document, where parallel chains are attempting
		//to transform the same data - if the pointer was the same they would content
		//so the document is duplicated and the duplicate handed off to the chain
		//
		//String id = (String)notification.get('id');
		//if (null != id && id.startsWith('015')) {
		//  Document document = [SELECT Id, Body FROM Document WHERE Id = :id];
		//  Document clone = document.clone();
		//  insert clone;
		//  event.put('id', clone.Id);
		//}
		
		return Utility.convert(new List<Map<String,Object>>{notification, clone});
	}
}