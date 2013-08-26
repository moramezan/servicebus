global class Publish implements Processable {
	
	global List<Map<String,Object>> execute(Map<String,Object> notification) {
		//get config of chain name to publish to
		String publishTo = 'subChain';
		
		if (publishTo == (String)notification.get('chainName')) {
			System.assert(false, 'Not allowed to publish to own chain!');
		}
		
		//careful: by returning 2 notification, the broker may think the process was a splitter
		Map<String,Object> event = notification.clone();
		event.put('chainName', publishTo);
		event.put('sequence', 0);
		
		//TODO
		//we might have an inbound document, where parallel chains are attempting
		//to transform the same data - if the pointer was the same they would content
		//so the document is duplicated and the duplicate handed off to the chain
		//
		//String id = (String)notification.get('id');
		//if (null != id && id.startsWith('015')) {
		//	Document document = [SELECT Id, Body FROM Document WHERE Id = :id];
		//	Document clone = document.clone();
		//	insert clone;
		//	event.put('id', clone.Id);
		//}
		
		return new List<Map<String,Object>>{notification, event};
	}

}