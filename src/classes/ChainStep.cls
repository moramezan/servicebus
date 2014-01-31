public class ChainStep extends SalesforceObject {

    public ChainStep(ChainStep__c chainStep) {
        super(chainStep);
    }
    
    public void moveBefore(Id beforeStepId) {
        ChainStep__c stepToMove = (ChainStep__c)this.getSObject();
        ChainStep__c beforeStep = (ChainStep__c)SalesforceObject.getById(beforeStepId);
        
        //find all steps EXCEPT the guy we are moving
        List<ChainStep__c> readChainSteps = [
            SELECT Id
            FROM ChainStep__c
            WHERE Chain__c = :stepToMove.Chain__c
            AND Id != :stepToMove.Id
            ORDER BY Sequence__c ASC
        ];
        
        //normal case: inject the guy we are moving amongst the others
        List<ChainStep__c> writeChainSteps = new List<ChainStep__c>();
        for (ChainStep__c chainStep : readChainSteps) {
            if (chainStep.Id == beforeStep.Id) writeChainSteps.add(stepToMove);
            writeChainSteps.add(chainStep);
        }
        
        //resequence them
        Integer sequence = 1;
        for (ChainStep__c chainStep : writeChainSteps) chainStep.Sequence__c = sequence++;
        update writeChainSteps;
    }
    
    public void moveAfter(Id afterStepId) {
        ChainStep__c stepToMove = (ChainStep__c)this.getSObject();
        ChainStep__c afterStep = (ChainStep__c)SalesforceObject.getById(afterStepId);
        
        //find all steps EXCEPT the guy we are moving
        List<ChainStep__c> readChainSteps = [
            SELECT Id
            FROM ChainStep__c
            WHERE Chain__c = :stepToMove.Chain__c
            AND Id != :stepToMove.Id
            ORDER BY Sequence__c ASC
        ];
        
        //normal case: inject the guy we are moving amongst the others
        List<ChainStep__c> writeChainSteps = new List<ChainStep__c>();
        for (ChainStep__c chainStep : readChainSteps) {
            writeChainSteps.add(chainStep);
            if (chainStep.Id == afterStep.Id) writeChainSteps.add(stepToMove);
        }
        
        //resequence them
        Integer sequence = 1;
        for (ChainStep__c chainStep : writeChainSteps) chainStep.Sequence__c = sequence++;
        update writeChainSteps;
    }
    
}