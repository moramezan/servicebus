global class Mark implements Processable {

	global List<Map<String,Object>> execute(Map<String,Object> notification) {
		//create a grouping id for what will ultimately be gated
		GateGroup__c gateGroup = new GateGroup__C();
		insert gateGroup;
		
		//annotate this step as the marker, so the following step must be a splitter
		notification.put('eda__markCount', 0);
		notification.put('eda__gateGroupId', gateGroup.Id);
		
		return new List<Map<String,Object>>{notification};
	}
	
}