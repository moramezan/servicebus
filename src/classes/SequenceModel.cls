public with sharing class SequenceModel extends ApexDomain.StandardModel {

    public class SequenceException extends Exception {}
    
    public SequenceModel(Sequence__c sequence) {
        super(sequence);
    }
    
    public StepSetModel fetchSteps() {
        List<String> fields = new List<String>();
        
        //step fields
        Set<String> stepFields = SObjectType.Step__c.Fields.getMap().keySet();
        for (String stepField : SObjectType.Step__c.Fields.getMap().keySet()) fields.add(stepField);
        
        //process fields
        Set<String> processFields = SObjectType.Process__c.Fields.getMap().keySet();
        for (String processField : SObjectType.Process__c.Fields.getMap().keySet()) fields.add(SObjectType.Step__c.Fields.Process__c.RelationshipName + '.' + processField);
        
        String sequenceId = this.getRecord().Id;
        String orderBy = SObjectType.Step__c.Fields.Position__c.Name;
        List<Step__c> steps = Database.query('SELECT ' + String.join(fields, ',') + ' FROM Step__c WHERE Sequence__c = :sequenceId ORDER BY ' + orderBy);
        
        //ConfigName field from related configs
        for (Step__c step : steps) {
            //Yes, we are doing SOQL inside a for-loop here!
            //We cannot SOQL or SOSL across multiple objects:
            //http://salesforce.stackexchange.com/q/24877/320
            //One improvement would be to use SOAP retrieve(),
            //but the Remote Site Setting has post-install steps.
            Id configId = step.ConfigId__c;
            if (null == configId) continue;
            String objectType = configId.getSObjectType().getDescribe().getName();
            SObject config = Database.query('SELECT Id, Name FROM ' + objectType + ' WHERE Id = :configId');
            String configName = (String)config.get('Name');
            step.ConfigName__c = configName.left(80);
        }
        
        return new StepSetModel(steps);
    }
    
    public StepModel appendStep(Id processId) {
        if (!SObjectType.Step__c.Createable) throw new ApexDomain.CrudException('!SObjectType.Step__c.Createable');
    
        Step__c step = new Step__c(
            Sequence__c = this.getRecord().Id,
            Process__c = processId
            //Position__c is automatic
        );
        
        insert step;
        return new StepModel(step);
    }
    
    /**
     * If this sequence contains no Terminate step, append one.
     * (Invoked by the user interface when viewing a Sequence for the first time)
     */
    public void terminate() {
        Sequence__c sequence = (Sequence__c)this.getRecord();
        
        Process__c terminateProcess = [
            SELECT Id
            FROM Process__c
            WHERE FullyQualifiedClassName__c = :Terminate.class.getName()
        ];
        
        try {
            Step__c terminateStep = [
                SELECT Id
                FROM Step__c
                WHERE Sequence__c = :sequence.Id AND Process__c = :terminateProcess.Id
            ];
        } catch (QueryException e) {
            //sequence contains no terminate step
            this.appendStep(terminateProcess.Id);
        }
    }
    
    public StepSetModel destroySteps(Set<Id> stepIds) {
        if (!SObjectType.Step__c.Deletable) throw new ApexDomain.CrudException('!SObjectType.Step__c.Deletable');
        if (!SObjectType.Step__c.Fields.Position__c.Updateable) throw new ApexDomain.FlsException('!SObjectType.Step__c.Fields.Position__c.Updateable');
        
        Sequence__c sequence = (Sequence__c)this.getRecord();
        
        List<Step__c> stepsToDelete = [
            SELECT Id, Sequence__c
            FROM Step__c
            WHERE Id IN :stepIds
        ];
        
        //validate
        for (Step__c stepToDelete : stepsToDelete) {
            if (stepToDelete.Sequence__c != sequence.Id) {
                throw new SequenceException('Cannot destroy step ' + stepToDelete.Id + ' from different sequence ' + sequence.Id);
            }
        }
        
        //perform the delete
        delete stepsToDelete;
        
        //find the remaining steps
        List<Step__c> stepsToReorder = [
            SELECT Id
            FROM Step__c
            WHERE Sequence__c = :sequence.Id
            ORDER BY Position__c ASC
        ];
        
        //reposition them
        Integer position = 1;
        for (Step__c stepToReorder : stepsToReorder) stepToReorder.Position__c = position++;
        update stepsToReorder;
        
        //hand back wrapped deleted steps
        return new StepSetModel(stepsToDelete);
    }

}