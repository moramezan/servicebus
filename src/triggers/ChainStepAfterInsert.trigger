/**
 * If a step's process has configuration, we need to insert the configuration at the same
 * time as the step. (We used to do this when the user attempted to view the configuration
 * for the first time, but that does DML from a Visualforce action and fails security review.)
 */
trigger ChainStepAfterInsert on ChainStep__c (after insert) {
	
	//re-query to get all apex classnames used in any of these new chainsteps
	Map<Id,ChainStep__c> id2step = new Map<Id,ChainStep__c>([SELECT Process__r.Name FROM ChainStep__c WHERE Id IN :Trigger.newMap.keySet()]);
	
	//prepare for any new configuration records
	Map<Id,SObject> id2config = new Map<Id,SObject>();
	
	for (ChainStep__c chainStep : Trigger.new) {
		//get apex class name from traversed process
		String apexClass = id2step.get(chainStep.Id).Process__r.Name;
		
		//instantiate each potential configurable process
		Type reflector = Type.forName(apexClass);
		Process.Plugin instance = (Process.Plugin)reflector.newInstance();
		Map<String,Object> meta = Utility.meta(instance.describe().Description);
		String edaConfigurable = (String)meta.get('eda__configurable');
		
		//get out of dodge quick if process is not configurable
		if (null == edaConfigurable) continue;
		
		//invoke the method to get an insertable configuration record
		Type configurableObject = Type.forName(edaConfigurable);
		SObject configuration = (SObject)configurableObject.newInstance();
		
		//prepare config for insertion
		id2config.put(chainStep.Id, configuration);
	}
	
	//insert configs
	insert id2config.values();
	
	//prepare chainsteps for update
	for (Id chainId : id2config.keySet()) {
		SObject config = id2config.get(chainId);
		ChainStep__c chainStep = id2step.get(chainId);
		chainStep.Configuration__c = config.Id;
	}
	
	//update chainsteps
	update id2step.values();
	
}