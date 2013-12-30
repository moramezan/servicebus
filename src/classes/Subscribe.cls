public class Subscribe implements Process.Plugin{
	
	public Process.PluginDescribeResult describe() {
		Process.PluginDescribeResult result = new Process.PluginDescribeResult();
		result.Description = '{"eda__configurable":"'+Schema.SObjectType.SubscribeConfiguration__c.Name+'"}';
		return result;
	}
	
	public Process.PluginResult invoke(Process.PluginRequest request) {
		return Utility.convert(new List<Map<String,Object>>{request.inputParameters});
	}

}