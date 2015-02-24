public with sharing class StepSetModel extends ApexDomain.StandardSetModel {
    
    public StepSetModel(List<Step__c> sobjects) {
        super(sobjects);
    }
    
    public override void onBeforeInsert() {
        this.incrementPositions();
        this.generateNames();
        this.insertConfigs();
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
        //get all involved steps
        List<Step__c> steps = this.getRecords();
        
        //get map of related sequences
        Set<Id> sequenceIds = new Set<Id>();
        for (Step__c step : steps) sequenceIds.add(step.Sequence__c);
        Map<Id,Sequence__c> id2sequence = new Map<Id,Sequence__c>([
            SELECT Id, StepsCount__c
            FROM Sequence__c
            WHERE Id IN :sequenceIds
        ]);
        
        //increment 
        for (Step__c step : steps) {
            //only touch steps whose position is zero (unspecified)
            if (step.Position__c != 0) continue;
            
            Sequence__c sequence = id2sequence.get(step.Sequence__c);
            step.Position__c = sequence.StepsCount__c + 1;
        }
    }
    
    /**
     * Formerly taken care of by SequenceNameAndPosition__c formula.
     * But now we need to make sure that this composite key is set.
     */
    private void generateNames() {
        List<Step__c> steps = this.getRecords();
        
        //get map of related sequences
        Set<Id> sequenceIds = new Set<Id>();
        for (Step__c step : steps) sequenceIds.add(step.Sequence__c);
        Map<Id,Sequence__c> id2sequence = new Map<Id,Sequence__c>([
            SELECT Id, Name, StepsCount__c
            FROM Sequence__c
            WHERE Id IN :sequenceIds
        ]);
        
        //generate 
        for (Step__c step : steps) {
            Sequence__c sequence = id2sequence.get(step.Sequence__c);
            step.Name = sequence.Name + '#' + step.Position__c;
        }
    }
    
    /**
     * If a step's process has config, we need to insert the config at the same
     * time as the step. (We used to do this when the user attempted to view the config
     * for the first time, but that does DML from a Visualforce action and fails security review.)
     */
    private void insertConfigs() {
        //get all involved steps
        List<Step__c> steps = this.getRecords();
        
        //and their respective process ids
        Set<Id> processIds = new Set<Id>();
        for (Step__c step : steps) processIds.add(step.Process__c);
        
        //query process ids to their config objects
        List<Process__c> processes = [SELECT Id, StepConfig__c FROM Process__c WHERE Id IN :processIds];
        
        //assemble a mapping of process ids to config object strings
        Map<Id,String> processId2stepConfig = new Map<Id,String>();
        for (Process__c process : processes) processId2stepConfig.put(process.Id, process.StepConfig__c);
        
        //we will do applicable steps and configs in tandem
        List<Step__c> configuredSteps = new List<Step__c>();
        List<SObject> configs = new List<SObject>();
        
        //assemble applicable steps and configs
        for (Step__c step : steps) {
            String stepConfig = processId2stepConfig.get(step.Process__c);
            if (stepConfig != null) {
                SObject config = (SObject)Type.forName(stepConfig).newInstance();
                configuredSteps.add(step);
                configs.add(config);
            }
        }
        
        insert configs;
        
        //reconcile the config ids back onto the steps
        for (Integer i = 0; i < configuredsteps.size(); i++) {
            Step__c step = configuredsteps[i];
            SObject config = configs[i];
            step.ConfigId__c = config.Id;
        }
    }
    
    /**
     * If a step has config, there is a one-to-one relationship.
     * StepAfterInsert takes care of the creation of the config.
     * This trigger takes care of the deletion of the config.
     */
    private void deleteConfigs() {
        if (!SObjectType.Step__c.Deletable) throw new ApexDomain.CrudException('!SObjectType.Step__c.Deletable');  
        Set<Id> stepIds = (new Map<Id,SObject>(this.getRecords())).keySet();
        Map<Id,Step__c> id2step = new Map<Id,Step__c>([SELECT id, Name, ConfigId__c FROM Step__c WHERE Id IN :stepIds]);
        
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