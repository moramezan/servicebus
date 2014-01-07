public class Wiretap implements Process.Plugin, Database.Stateful{
	
	public Process.PluginDescribeResult describe() {
		Process.PluginDescribeResult describeResult = new Process.PluginDescribeResult();
		describeResult.Name = 'Wiretap';
		describeResult.Description = 'No-op process that forwards the serialized Notification to the email of the running context user';
		describeResult.Tag = 'Event Driven Architecture';
		return describeResult;
	}
	
	public Process.PluginResult invoke(Process.PluginRequest request) {
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