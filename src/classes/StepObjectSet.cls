public class StepObjectSet extends SalesforceObjectSet {
    
    public StepObjectSet(List<Step__c> sobjects) {
        super(sobjects);
    }
    
    public override void onBeforeInsert() {
        this.incrementPositions();
        this.insertConfigurations();
    }
    
    public override void onBeforeDelete() {
        this.deleteConfigurations();
    }
    
    @TestVisible static private Step__c generateOne(Id sequenceId, Id processId) {
        Step__c step = new Step__c(
            Sequence__c = sequenceId,
            Process__c = processId
            //Position__c is automatic
        );
        
        insert step;
        
        //requery
        return (Step__c)SalesforceObject.getById(step.Id);
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
        List<Step__c> steps = this.getSObjects();
        
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
     * If a step's process has configuration, we need to insert the configuration at the same
     * time as the step. (We used to do this when the user attempted to view the configuration
     * for the first time, but that does DML from a Visualforce action and fails security review.)
     */
    private void insertConfigurations() {
        //get all involved steps
        List<Step__c> steps = this.getSObjects();
        
        //and their respective process ids
        Set<Id> processIds = new Set<Id>();
        for (Step__c step : steps) processIds.add(step.Process__c);
        
        //query process ids to their config objects
        List<Process__c> processes = [SELECT Id, ConfigObject__c FROM Process__c WHERE Id IN :processIds];
        
        //assemble a mapping of process ids to config object strings
        Map<Id,String> processId2configObject = new Map<Id,String>();
        for (Process__c process : processes) processId2configObject.put(process.Id, process.ConfigObject__c);
        
        //we will do applicable steps and configurations in tandem
        List<Step__c> configuredSteps = new List<Step__c>();
        List<SObject> configurations = new List<SObject>();
        
        //assemble applicable steps and configurations
        for (Step__c step : steps) {
            String configObject = processId2configObject.get(step.Process__c);
            if (configObject != null) {
                SObject configuration = (SObject)Type.forName(configObject).newInstance();
                configuredSteps.add(step);
                configurations.add(configuration);
            }
        }
        
        insert configurations;
        
        //reconcile the configuration ids back onto the steps
        for (Integer i = 0; i < configuredsteps.size(); i++) {
            Step__c step = configuredsteps[i];
            SObject configuration = configurations[i];
            step.ConfigurationId__c = configuration.Id;
        }
    }
    
    /**
     * If a step has configuration, there is a one-to-one relationship.
     * StepAfterInsert takes care of the creation of the configuration.
     * This trigger takes care of the deletion of the configuration.
     */
    private void deleteConfigurations() {
        Set<Id> stepIds = (new Map<Id,SObject>(this.getSObjects())).keySet();
        Map<Id,Step__c> id2step = new Map<Id,Step__c>([SELECT id, Name, ConfigurationId__c FROM Step__c WHERE Id IN :stepIds]);
        
        //prepare list of configuration ids
        List<Id> ids = new List<Id>();
        
        //enumerate steps to get configuration ids
        for (Step__c step : id2step.values()) {
            if (null == step.ConfigurationId__c) continue;
            ids.add(step.ConfigurationId__c);
        }
        
        //delete all the configuration records
        if (!ids.isEmpty()) {
            //don't choke on steps with no config
            Database.delete(ids);
            Database.emptyRecycleBin(ids);
        }
    }
}