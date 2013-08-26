global class Sink implements Processable {
	
	global List<Map<String,Object>> execute(Map<String,Object> notification) {
        List<Map<String,Object>> notifications = new List<Map<String,Object>>();
        
        //if we got here from a boomerang, back to where you came from!
        String boomerangChainStep = (String)notification.get('boomerangChainName');
        Decimal boomerangSequence = (Decimal)notification.get('boomerangSequence');
        if (null != boomerangChainStep && null != boomerangSequence) {
            notification.remove('boomerangChainName');
            notification.remove('boomerangSequence');
            notification.put('chainName', boomerangChainStep);
            notification.put('sequence', boomerangSequence);
            notifications.add(notification);
        }
        
		return notifications;
	}
	
}