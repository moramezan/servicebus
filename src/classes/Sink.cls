global class Sink implements Processable {
	
	global List<Map<String,Object>> execute(Map<String,Object> notification) {
		List<Map<String,Object>> notifications = new List<Map<String,Object>>();
		
		//if we got here from a boomerang, back to where you came from!
		String boomerangChainStep = (String)notification.get('eda__boomerangChainName');
		Decimal boomerangSequence = (Decimal)notification.get('eda__boomerangSequence');
		if (null != boomerangChainStep && null != boomerangSequence) {
			notification.remove('eda__boomerangChainName');
			notification.remove('eda__boomerangSequence');
			notification.put('eda__chainName', boomerangChainStep);
			notification.put('eda__sequence', boomerangSequence);
			notifications.add(notification);
		}
		
		return notifications;
	}
	
}