global class Wiretap implements Process.Plugin {
	
	global Process.PluginDescribeResult describe() {
		return new Process.PluginDescribeResult();
	}
	
	global Process.PluginResult invoke(Process.PluginRequest request) {
		Map<String,Object> notification = request.inputParameters;
		
		Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
		message.setSubject('[Wiretap] ' + notification.get('eda__chainName') + '#' + notification.get('eda__sequence'));
		message.setPlainTextBody(Json.serialize(notification));
		message.setTargetObjectId(UserInfo.getUserId());
		message.setSaveAsActivity(false);
		Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{message});
		
		return new Process.PluginResult(new Map<String,Object>{'0' => notification});
	}
}