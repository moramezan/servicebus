public class Mark implements Process.Plugin, Database.Stateful {
	
	public Process.PluginDescribeResult describe() {
		Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
		plugin.Description = 'Marks splitted notifications with an association key. Next process must be a split.';
		plugin.Tag = 'Event Driven Architecture';
		
		plugin.OutputParameters = new List<Process.PluginDescribeResult.OutputParameter>{
			new Process.PluginDescribeResult.OutputParameter(
				'eda__markCount',
				'The broker will increment this to detect that the next process returned multiple notifications.',
				Process.PluginDescribeResult.ParameterType.INTEGER
			),
			new Process.PluginDescribeResult.OutputParameter(
				'eda__gateGroupId',
				'The Id of the Gate Group that eventually associates all the marked notifications.',
				Process.PluginDescribeResult.ParameterType.ID
			)
		};
		
		return plugin;
	}
	
	public Process.PluginResult invoke(Process.PluginRequest request) {
		Map<String,Object> notification = request.inputParameters;
		
		//create a grouping id for what will ultimately be gated
		GateGroup__c gateGroup = new GateGroup__C();
		insert gateGroup;
		
		//annotate this step as the marker, so the following step must be a splitter
		notification.put('eda__markCount', 0);
		notification.put('eda__gateGroupId', gateGroup.Id);
		
		return new Process.PluginResult(new Map<String,Object>{'0' => notification});
	}
	
}