public class Chains extends SObjects {

    public Chains(List<Chain__c> sobjects) {
        super(sobjects);
    }
    
    public override void onBeforeDelete() {
        this.cascadeDeletionTriggers();
    }
    
    /**
     * When deleting a MASTER, Salesforce does not fire the DETAIL delete triggers.
     * https://success.salesforce.com/ideaView?id=08730000000BqSJ
     * So we cascade the delete ourselves manually, to make sure they fire.
     */
    @testVisible private void cascadeDeletionTriggers() {
        Set<Id> chainIds = new Map<Id,SObject>(this.getSObjects()).keySet();
        List<ChainStep__c> chainSteps = [
            SELECT Id
            FROM ChainStep__c
            WHERE Chain__c IN :chainIds
        ];
        delete chainSteps;
    }
}