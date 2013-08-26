/**
 * When deleting a MASTER, Salesforce does not fire the DETAIL delete triggers.
 * https://success.salesforce.com/ideaView?id=08730000000BqSJ
 * So we cascade the delete ourselves manually, to make sure they fire.
 */
trigger ChainBeforeDelete on Chain__c (before delete) {
	
	Set<Id> chainIds = Trigger.oldMap.keySet();
	
	List<ChainStep__c> chainSteps = [
		SELECT Id
		FROM ChainStep__c
		WHERE Chain__c IN :chainIds
	];
	
	delete chainSteps;
	
}