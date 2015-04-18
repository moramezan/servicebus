public with sharing class SequenceModel extends ApexDomain.StandardModel {

    public class SequenceException extends Exception {}
    
    private Sequence__c Sequence;
    
    public Sequence__c getSequence() {
        return this.sequence;
    }
    
    private SequenceModel(Sequence__c sequence) {
        super(sequence);
        this.Sequence = sequence;
    }
   
    static public SequenceModel fromName(String sequenceName) {
        Sequence__c sequence = [SELECT Id FROM Sequence__c WHERE Name = :sequenceName];
        sequence = (Sequence__c)ApexDomain.getById(sequence.Id);
        return new SequenceModel(sequence);
    }
    
    public List<Step__c> fetchSteps() {
        return [
            SELECT Id, ConfigId__c, ConfigName__c, FullyQualifiedClassName__c, Position__c, SequenceName__c
            FROM Step__c
            WHERE SequenceName__c = :this.Sequence.Name
            ORDER BY Position__c ASC
        ];
    }
    
    public Step__c appendStep(String fullyQualifiedClassName) {
        if (!SObjectType.Step__c.Createable) throw new ApexDomain.CrudException('!SObjectType.Step__c.Createable');
        
        //insert any StepConfig
        ProcessModel process = ProcessModel.fromFqcn(fullyQualifiedClassName);
        SObject config;
        if (process.StepConfig != null) {
            config = (SObject)Type.forName(process.StepConfig).newInstance();
            insert config;
            config = ApexDomain.getById(config.Id);
        }
        
        Integer position = [SELECT COUNT() FROM Step__c WHERE SequenceName__c = :this.Sequence.Name] + 1;
        
        //insert step himself
        Step__c step = new Step__c(
            Name = this.Sequence.Name + '#' + position,
            SequenceName__c = this.Sequence.Name,
            FullyQualifiedClassName__c = fullyQualifiedClassName,
            Position__c = position
        );
        
        if (config != null) {
            step.ConfigId__c = (Id)config.get('Id');
            step.ConfigName__c = (String)config.get('Name');
        }
        
        insert step;
        return (Step__c)ApexDomain.getById(step.Id);
    }
    
    /**
     * If this sequence contains no Terminate step, append one.
     * (Invoked by the user interface when viewing a Sequence for the first time)
     */
    public void terminate() {
        try {
            Step__c terminateStep = [
                SELECT Id
                FROM Step__c
                WHERE SequenceName__c = :this.Sequence.Name AND FullyQualifiedClassName__c = :Terminate.class.getName()
            ];
        } catch (QueryException e) {
            //sequence contains no terminate step
            this.appendStep(Terminate.class.getName());
        }
    }
    
    public StepSetModel destroySteps(Set<Id> stepIds) {
        if (!SObjectType.Step__c.Deletable) throw new ApexDomain.CrudException('!SObjectType.Step__c.Deletable');
        if (!SObjectType.Step__c.Fields.Position__c.Updateable) throw new ApexDomain.FlsException('!SObjectType.Step__c.Fields.Position__c.Updateable');
        
        List<Step__c> stepsToDelete = [
            SELECT Id, ConfigId__c
            FROM Step__c
            WHERE Id IN :stepIds
        ];
        
        //perform the delete
        delete stepsToDelete;
        
        //any configs to delete
        List<Id> configIds = new List<Id>();
        for (Step__c stepToDelete : stepsToDelete) if (stepToDelete.ConfigId__c != null) configIds.add(stepToDelete.ConfigId__c);
        Database.delete(configIds);
        
        //find the remaining steps
        List<Step__c> stepsToReorder = [
            SELECT Id
            FROM Step__c
            WHERE SequenceName__c = :this.Sequence.Name
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