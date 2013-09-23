/**
 * If a step has configuration, there is a one-to-one relationship.
 * ChainStepAfterInsert takes care of the creation of the configuration.
 * This trigger takes care of the deletion of the configuration.
 */
trigger ChainStepBeforeDelete on ChainStep__c (before delete) {
	
	Map<Id,ChainStep__c> id2step = Trigger.oldMap;
	
	//prepare list of configuration ids
	List<Id> ids = new List<Id>();
	
	//enumerate chain steps to get configuration ids
	for (ChainStep__c chainStep : id2step.values()) {
		if (null == chainStep.Configuration__c) continue;
		ids.add(chainStep.Configuration__c);
	}
	
	//delete all the configuration records
	Database.delete(ids);
	
}