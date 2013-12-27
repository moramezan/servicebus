global class Boomerang implements Process.Plugin {
	
	global Process.PluginDescribeResult describe() {
		Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
		plugin.Description = 'Boomerang process perverts execution. {"eda__configurable":"BoomerangConfiguration__c"}';
		
		plugin.outputParameters = new List<Process.PluginDescribeResult.OutputParameter>{
			new Process.PluginDescribeResult.OutputParameter(
				'eda__boomerangChainName',
				'Marks the chain name which the Boomerang returns to.',
				Process.PluginDescribeResult.ParameterType.STRING
			),
			new Process.PluginDescribeResult.OutputParameter(
				'eda__boomerangSequence',
				'Marks the sequence number which the Boomerang returns to.',
				Process.PluginDescribeResult.ParameterType.INTEGER
			)
		};
		return plugin;
	}
	
	global Process.PluginResult invoke(Process.PluginRequest request) {
		Map<String,Object> notification = request.inputParameters;
		
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
		
		return Utility.convert(new List<Map<String,Object>>{notification});
	}
}