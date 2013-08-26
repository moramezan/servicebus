global class Wiretap implements Processable {

	global List<Map<String,Object>> execute(Map<String,Object> notification) {
		Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
		message.setSubject(notification.get('chainName') + '#' + notification.get('sequence'));
		message.setPlainTextBody(Json.serialize(notification));
		message.setTargetObjectId(UserInfo.getUserId());
		message.setSaveAsActivity(false);
		
		Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{message});
		return new List<Map<String,Object>>{notification};
	}
	
}