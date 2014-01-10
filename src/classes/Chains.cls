public class Chains extends SObjects {

	/**
	 * When deleting a MASTER, Salesforce does not fire the DETAIL delete triggers.
	 * https://success.salesforce.com/ideaView?id=08730000000BqSJ
	 * So we cascade the delete ourselves manually, to make sure they fire.
	 */
	public override void onBeforeDelete(Map<Id,SObject> objects) {
		Set<Id> chainIds = objects.keySet();
		
		List<ChainStep__c> chainSteps = [
			SELECT Id
			FROM ChainStep__c
			WHERE Chain__c IN :chainIds
		];
		
		delete chainSteps; 
	}
}