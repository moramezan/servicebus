global class Sink implements Process.Plugin {
	
	global Process.PluginDescribeResult describe() {
		return new Process.PluginDescribeResult();
	}
	
	global Process.PluginResult invoke(Process.PluginRequest request) {
		Map<String,Object> notification = request.inputParameters;
		
		//if we got here from a boomerang, back to where you came from!
		Map<String,Object> notifications = new Map<String,Object>();
		String boomerangChainStep = (String)notification.get('eda__boomerangChainName');
		Decimal boomerangSequence = (Decimal)notification.get('eda__boomerangSequence');
		if (null != boomerangChainStep && null != boomerangSequence) {
			notification.remove('eda__boomerangChainName');
			notification.remove('eda__boomerangSequence');
			notification.put('eda__chainName', boomerangChainStep);
			notification.put('eda__sequence', boomerangSequence);
			notifications.put('0', notification);
		}
		
		return new Process.PluginResult(notifications);
	}

}