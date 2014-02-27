public class Sequence extends SalesforceObject {

    public class SequenceException extends Exception {}
    
    public Sequence(Sequence__c sequence) {
        super(sequence);
    }
    
    public Steps fetchSteps() {
        List<String> fields = new List<String>();
        
        //step fields
        Set<String> stepFields = SObjectType.Step__c.Fields.getMap().keySet();
        for (String stepField : SObjectType.Step__c.Fields.getMap().keySet()) fields.add(stepField);
        
        //process fields
        Set<String> processFields = SObjectType.Process__c.Fields.getMap().keySet();
        for (String processField : SObjectType.Process__c.Fields.getMap().keySet()) fields.add(SObjectType.Step__c.Fields.Process__c.RelationshipName + '.' + processField);
        
        String sequenceId = this.getSObject().Id;
        String orderBy = SObjectType.Step__c.Fields.Position__c.Name;
        List<Step__c> steps = Database.query('SELECT ' + String.join(fields, ',') + ' FROM Step__c WHERE Sequence__c = :sequenceId ORDER BY ' + orderBy);
        
        //ConfigurationName field from related configs
        for (Step__c step : steps) {
            Id configurationId = step.ConfigurationId__c;
            if (null == configurationId) continue;
            String objectType = configurationId.getSObjectType().getDescribe().getName();
            SObject config = Database.query('SELECT Id, Name FROM ' + objectType + ' WHERE Id = :configurationId');
            String configurationName = (String)config.get('Name');
            step.ConfigurationName__c = configurationName.left(80);
        }
        
        return new Steps(steps);
    }
    
    public Step appendStep(Id processId) {
        Step__c step = new Step__c(
            Sequence__c = this.getSObject().Id,
            Process__c = processId
            //Position__c is automatic
        );
        
        insert step;
        return new Step(step);
    }
    
    /**
     * If this sequence contains no Terminate step, append one.
     * (Invoked by the user interface when viewing a Sequence for the first time)
     */
    public void terminate() {
        Sequence__c sequence = (Sequence__c)this.getSObject();
        
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
    
    public Step deleteStep(Id stepId) {
        //validate and perform the delete
        Sequence__c sequence = (Sequence__c)this.getSObject();
        Step__c step = (Step__c)SalesforceObject.getById(stepId);
        if (sequence.Id != step.Sequence__c)   throw new SequenceException('Cannot deleteStep from different sequence ' + sequence.Id + ' ' + step.Sequence__c);
        delete step;
        
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
        
        //hand back wrapped deleted step
        return new Step(step);
    }

}