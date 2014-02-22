public class Step extends SalesforceObject {

    public Step(Step__c step) {
        super(step);
    }
    
    public void moveBefore(Id beforeStepId) {
        Step__c stepToMove = (Step__c)this.getSObject();
        Step__c beforeStep = (Step__c)SalesforceObject.getById(beforeStepId);
        
        //find all steps EXCEPT the guy we are moving
        List<Step__c> readSteps = [
            SELECT Id
            FROM Step__c
            WHERE Chain__c = :stepToMove.Chain__c
            AND Id != :stepToMove.Id
            ORDER BY Sequence__c ASC
        ];
        
        //normal case: inject the guy we are moving amongst the others
        List<Step__c> writeSteps = new List<Step__c>();
        for (Step__c step : readSteps) {
            if (step.Id == beforeStep.Id) writeSteps.add(stepToMove);
            writeSteps.add(step);
        }
        
        //resequence them
        Integer sequence = 1;
        for (Step__c step : writeSteps) step.Sequence__c = sequence++;
        update writeSteps;
    }
    
    public void moveAfter(Id afterStepId) {
        Step__c stepToMove = (Step__c)this.getSObject();
        Step__c afterStep = (Step__c)SalesforceObject.getById(afterStepId);
        
        //find all steps EXCEPT the guy we are moving
        List<Step__c> readSteps = [
            SELECT Id
            FROM Step__c
            WHERE Chain__c = :stepToMove.Chain__c
            AND Id != :stepToMove.Id
            ORDER BY Sequence__c ASC
        ];
        
        //normal case: inject the guy we are moving amongst the others
        List<Step__c> writeSteps = new List<Step__c>();
        for (Step__c step : readSteps) {
            writeSteps.add(step);
            if (step.Id == afterStep.Id) writeSteps.add(stepToMove);
        }
        
        //resequence them
        Integer sequence = 1;
        for (Step__c step : writeSteps) step.Sequence__c = sequence++;
        update writeSteps;
    }
}