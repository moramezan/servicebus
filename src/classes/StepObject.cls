public with sharing class StepObject extends SalesforceObject {

    public StepObject(Step__c step) {
        super(step);
    }
    
    public void moveBefore(Id beforeStepId) {
        if (!SObjectType.Step__c.Fields.Position__c.Updateable) throw new SalesforceObject.FlsException('!SObjectType.Step__c.Fields.Position__c.Updateable');
        
        Step__c stepToMove = (Step__c)this.getSObject();
        Step__c beforeStep = (Step__c)SalesforceObject.getById(beforeStepId);
        
        //find all steps EXCEPT the guy we are moving
        List<Step__c> readSteps = [
            SELECT Id
            FROM Step__c
            WHERE Sequence__c = :stepToMove.Sequence__c
            AND Id != :stepToMove.Id
            ORDER BY Position__c ASC
        ];
        
        //normal case: inject the guy we are moving amongst the others
        List<Step__c> writeSteps = new List<Step__c>();
        for (Step__c step : readSteps) {
            if (step.Id == beforeStep.Id) writeSteps.add(stepToMove);
            writeSteps.add(step);
        }
        
        //reposition them
        Integer position = 1;
        for (Step__c step : writeSteps) step.Position__c = position++;
        update writeSteps;
    }
    
    public void moveAfter(Id afterStepId) {
        if (!SObjectType.Step__c.Fields.Position__c.Updateable) throw new SalesforceObject.FlsException('!SObjectType.Step__c.Fields.Position__c.Updateable');
        
        Step__c stepToMove = (Step__c)this.getSObject();
        Step__c afterStep = (Step__c)SalesforceObject.getById(afterStepId);
        
        //find all steps EXCEPT the guy we are moving
        List<Step__c> readSteps = [
            SELECT Id
            FROM Step__c
            WHERE Sequence__c = :stepToMove.Sequence__c
            AND Id != :stepToMove.Id
            ORDER BY Position__c ASC
        ];
        
        //normal case: inject the guy we are moving amongst the others
        List<Step__c> writeSteps = new List<Step__c>();
        for (Step__c step : readSteps) {
            writeSteps.add(step);
            if (step.Id == afterStep.Id) writeSteps.add(stepToMove);
        }
        
        //reposition them
        Integer position = 1;
        for (Step__c step : writeSteps) step.Position__c = position++;
        update writeSteps;
    }
    
    @TestVisible static private Step__c generateOne(Id sequenceId, Id processId) {
        if (!SObjectType.Step__c.Createable) throw new SalesforceObject.CrudException('!SObjectType.Step__c.Createable');
     
        Step__c step = new Step__c(
            Sequence__c = sequenceId,
            Process__c = processId
            //Position__c is automatic
        );
        
        insert step;
        
        //requery
        return (Step__c)SalesforceObject.getById(step.Id);
    }
    
}