public with sharing class StepModel extends ApexDomain.StandardModel {

    private Step__c step;
    
    public Step__c getStep() {
        return this.step;
    }
    
    private StepModel(Step__c step) {
        super(step);
        this.step = step;
    }
    
    static public StepModel fromId(Id stepId) {
        Step__c step = (Step__c)ApexDomain.getById(stepId);
        return new StepModel(step);
    }
    
    public void moveBefore(Id beforeStepId) {
        if (!SObjectType.Step__c.Fields.Position__c.Updateable) throw new ApexDomain.FlsException('!SObjectType.Step__c.Fields.Position__c.Updateable');
        
        Step__c stepToMove = this.step;
        Step__c beforeStep = (Step__c)ApexDomain.getById(beforeStepId);
        
        //find all steps EXCEPT the guy we are moving
        List<Step__c> readSteps = [
            SELECT Id
            FROM Step__c
            WHERE SequenceName__c = :stepToMove.SequenceName__c
            AND Id != :stepToMove.Id
            ORDER BY Position__c ASC
        ];
        
        //normal case: inject the guy we are moving amongst the others
        List<Step__c> writeSteps = new List<Step__c>();
        for (Step__c step : readSteps) {
            if (step.Id == beforeStep.Id) writeSteps.add(stepToMove);
            writeSteps.add(step);
        }
        
        //custom settings not smart enough to recognize uniqueness in bulk update
        //https://developer.salesforce.com/forums/ForumsMain?id=906F00000008zF5IAI
        //so we have to make them unique first so that we can overwrite them second
        for (Step__c step : writeSteps) step.Name = EncodingUtil.base64encode(Crypto.generateAesKey(192));
        update writeSteps;
        
        //reposition them all
        Integer position = 1;
        for (Step__c step : writeSteps) {
            step.Name = this.step.SequenceName__c + '#' + position;
            step.Position__c = position;
            position++;
        }
        
        update writeSteps;
    }
    
    public void moveAfter(Id afterStepId) {
        if (!SObjectType.Step__c.Fields.Position__c.Updateable) throw new ApexDomain.FlsException('!SObjectType.Step__c.Fields.Position__c.Updateable');
        
        Step__c stepToMove = this.step;
        Step__c afterStep = (Step__c)ApexDomain.getById(afterStepId);
        
        //find all steps EXCEPT the guy we are moving
        List<Step__c> readSteps = [
            SELECT Id
            FROM Step__c
            WHERE SequenceName__c = :stepToMove.SequenceName__c
            AND Id != :stepToMove.Id
            ORDER BY Position__c ASC
        ];
        
        //normal case: inject the guy we are moving amongst the others
        List<Step__c> writeSteps = new List<Step__c>();
        for (Step__c step : readSteps) {
            writeSteps.add(step);
            if (step.Id == afterStep.Id) writeSteps.add(stepToMove);
        }
        
        //custom settings not smart enough to recognize uniqueness in bulk update
        //https://developer.salesforce.com/forums/ForumsMain?id=906F00000008zF5IAI
        //so we have to make them unique first so that we can overwrite them second
        for (Step__c step : writeSteps) step.Name = EncodingUtil.base64encode(Crypto.generateAesKey(192));
        update writeSteps;
        
        //reposition them all
        Integer position = 1;
        for (Step__c step : writeSteps) {
            step.Name = this.step.SequenceName__c + '#' + position;
            step.Position__c = position;
            position++;
        }
        
        update writeSteps;
    }
    
    @TestVisible static private Step__c generateOne(String sequenceName, String fullyQualifiedClassName) {
        if (!SObjectType.Step__c.Createable) throw new ApexDomain.CrudException('!SObjectType.Step__c.Createable');
        SequenceModel model = SequenceModel.fromName(sequenceName);
        Step__c step = model.appendStep(fullyQualifiedClassName);
        return step;
    }
    
}