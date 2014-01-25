public class Chains extends SObjects {

    public Chains(List<Chain__c> sobjects) {
        super(sobjects);
    }
    
    public override void onBeforeDelete() {
        this.cascadeDeletions();
    }
    
    public override void onAfterInsert() {
        this.appendSinks();
    }
    
    /**
     * Because the terminating Sink is a mandatory part of every chain, we
     * make sure that all new Chains begin life with a Sink as the last process.
     */
    @testVisible private void appendSinks() {
        Set<Id> chainIds = new Map<Id,SObject>(this.getSObjects()).keySet();
        
        //note hard binding to apex class name instead of string
        Process__c sinkProcess = [
            SELECT Id
            FROM Process__c
            WHERE FullyQualifiedClassName__c = :Sink.class.getName()
        ];
        
        //bulkified for multiple chains
        List<ChainStep__c> chainSteps = new List<ChainStep__c>();
        for (Id chainId : chainIds) {
            chainSteps.add(new ChainStep__c(
                Chain__c = chainId,
                Process__c = sinkProcess.Id
                //Sequence__c set by workflow
            ));
        }
        
        insert chainSteps;
    }
    
    /**
     * When deleting a MASTER, Salesforce does not fire the DETAIL delete triggers.
     * https://success.salesforce.com/ideaView?id=08730000000BqSJ
     * So we cascade the delete ourselves manually, to make sure they fire.
     */
    @testVisible private void cascadeDeletions() {
        Set<Id> chainIds = new Map<Id,SObject>(this.getSObjects()).keySet();
        List<ChainStep__c> chainSteps = [
            SELECT Id
            FROM ChainStep__c
            WHERE Chain__c IN :chainIds
        ];
        delete chainSteps;
    }
}