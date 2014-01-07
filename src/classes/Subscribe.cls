public class Subscribe implements Process.Plugin, Database.Stateful {
	
	public Process.PluginDescribeResult describe() {
		Process.PluginDescribeResult result = new Process.PluginDescribeResult();
		result.Description = 'Subscribes to a named event {"eda__configurable":"'+Schema.SObjectType.SubscribeConfiguration__c.Name+'"}';
		result.Tag = 'Event Driven Architecture';
		return result;
	}
	
	public Process.PluginResult invoke(Process.PluginRequest request) {
		return Utility.convert(new List<Map<String,Object>>{request.inputParameters});
	}

}