public with sharing class Gate implements Process.Plugin, Database.Stateful {
	
	public Process.PluginDescribeResult describe() {
		Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
		plugin.Description = 'Gate process allows you to aggregate marked notifications on a common grouping key.';
		plugin.Tag = 'Event Driven Architecture';
		
		plugin.InputParameters = new List<Process.PluginDescribeResult.InputParameter>{
			new Process.PluginDescribeResult.InputParameter(
				'eda__gateGroupId',
				'Id of the GateGroup the marked notifications should belong to.',
				Process.PluginDescribeResult.ParameterType.ID,
				false
			),
			new Process.PluginDescribeResult.InputParameter(
				'eda__count',
				'Number of marked notifications the gate should expect.',
				Process.PluginDescribeResult.ParameterType.INTEGER,
				false
			)
		};
		
		plugin.OutputParameters = new List<Process.PluginDescribeResult.OutputParameter>{
			new Process.PluginDescribeResult.OutputParameter(
				'eda__id',
				'Id of the GateGroup whose members are now all present.',
				Process.PluginDescribeResult.ParameterType.ID
			)
		};
		
		return plugin;
	}
	
	public Process.PluginResult invoke(Process.PluginRequest request) {
		Map<String,Object> notification = request.inputParameters;
		
		Id gateGroupId = (Id)notification.get('eda__gateGroupId');
		Decimal count = (Decimal)notification.get('eda__count');
		
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
			return new Process.PluginResult(new Map<String,Object>());
		}   
		
		//this is the last item, let's release
		notification.put('eda__id', gateGroupId);
		
		return Utility.convert(new List<Map<String,Object>>{notification});
	}
	
}