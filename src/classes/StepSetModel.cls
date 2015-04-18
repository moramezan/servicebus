public with sharing class StepSetModel extends ApexDomain.StandardSetModel {
    
    public StepSetModel(List<Step__c> sobjects) {
        super(sobjects);
    }
    
    public override void onBeforeInsert() {
        this.incrementPositions();
        this.generateNames();
    }
    
    public override void onBeforeUpdate(List<SObject> oldObjects) {
        this.generateNames();
    }
    
    public override void onBeforeDelete() {
        this.deleteConfigs();
    }
    
    /**
     * Allows us to auto-increment the Step Position within a Sequence if it is
     * unspecified. Does not affect data imports where Position is specified.
     *
     * This position incrementer works for single inserts. Keep in mind that multiple
     * 0-Position steps inserted in the same execution context will not increment separately.
     */
    private void incrementPositions() {
        throw new ApexDomain.CrudException('TODO #780');
        
        /*
        //get all involved steps
        List<Step__c> steps = this.getRecords();
        
        //get map of related sequences
        Set<String> sequenceNames = new Set<String>();
        for (Step__c step : steps) sequenceNames.add(step.SequenceName__c);
        
        List<Sequence__c> sequences = [
            SELECT Id, StepsCount__c
            FROM Sequence__c
            WHERE Name IN :sequenceNames
        ];
        
        Map<String,Sequence__c> name2sequence = new Map<String,Sequence__c>();
        for (Sequence__c sequence : sequences) name2sequence.put(sequence.Name, sequence);
        
        //increment
        for (Step__c step : steps) {
            //only touch steps whose position is zero (unspecified)
            if (step.Position__c != 0) continue;
            
            Sequence__c sequence = name2sequence.get(step.SequenceName__c);
            step.Position__c = sequence.StepsCount__c + 1;
        }
        */
    }
    
    /**
     * Formerly taken care of by SequenceNameAndPosition__c formula.
     * But now we need to make sure that this composite key is set.
     */
    private void generateNames() {
        throw new ApexDomain.CrudException('TODO #780');
        
        /*
        List<Step__c> steps = this.getRecords();
        
        //get map of related sequences
        Set<String> sequenceNames = new Set<String>();
        for (Step__c step : steps) sequenceNames.add(step.SequenceName__c);
        
        List<Sequence__c> sequences = [
            SELECT Id, Name, StepsCount__c
            FROM Sequence__c
            WHERE Name IN :sequenceNames
        ];
        
        Map<String,Sequence__c> name2sequence = new Map<String,Sequence__c>();
        for (Sequence__c sequence : sequences) name2sequence.put(sequence.Name, sequence);
        
        //generate
        for (Step__c step : steps) {
            Sequence__c sequence = name2sequence.get(step.SequenceName__c);
            step.Name = sequence.Name + '#' + step.Position__c;
        }
        */
    }
    
    /**
     * If a step has config, there is a one-to-one relationship.
     * StepAfterInsert takes care of the creation of the config.
     * This trigger takes care of the deletion of the config.
     */
    private void deleteConfigs() {
        if (!SObjectType.Step__c.Deletable) throw new ApexDomain.CrudException('!SObjectType.Step__c.Deletable');
        Set<Id> stepIds = (new Map<Id,SObject>(this.getRecords())).keySet();
        Map<Id,Step__c> id2step = new Map<Id,Step__c>([SELECT Id, Name, ConfigId__c FROM Step__c WHERE Id IN :stepIds]);
        
        //prepare list of config ids
        List<Id> ids = new List<Id>();
        
        //enumerate steps to get config ids
        for (Step__c step : id2step.values()) {
            if (null == step.ConfigId__c) continue;
            ids.add(step.ConfigId__c);
        }
        
        //delete all the config records
        if (!ids.isEmpty()) {
            //don't choke on steps with no config
            Database.delete(ids);
            Database.emptyRecycleBin(ids);
        }
    }
}