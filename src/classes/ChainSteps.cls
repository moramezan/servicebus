public class ChainSteps extends SObjects {
    
    public ChainSteps(List<ChainStep__c> sobjects) {
        super(sobjects);
    }
    
    public override void onBeforeInsert() {
        this.insertConfigurations();
    }
    
    public override void onBeforeDelete() {
        this.deleteConfigurations();
    }
    
    @testVisible static private ChainStep__c generateOne(Id chainId, Id processId) {
        ChainStep__c chainStep = new ChainStep__c(
            Chain__c = chainId,
            Process__c = processId
            //Sequence__c is automatic
        );
        
        insert chainStep; 
        
        //requery
        return [
            SELECT Id, Chain__c, Sequence__c, Process__c, ConfigurationId__c
            FROM ChainStep__c
            WHERE Id = :chainStep.Id
        ];
    }
    
    /**
     * If a step's process has configuration, we need to insert the configuration at the same
     * time as the step. (We used to do this when the user attempted to view the configuration
     * for the first time, but that does DML from a Visualforce action and fails security review.)
     */
    private void insertConfigurations() {
        //get all involved chain steps
        List<ChainStep__c> chainSteps = this.getSObjects();
        
        //and their respective process ids
        Set<Id> processIds = new Set<Id>();
        for (ChainStep__c chainStep : chainSteps) processIds.add(chainStep.Process__c);
        
        //query process ids to their configurables
        List<Process__c> processes = [SELECT Id, Configurable__c FROM Process__c WHERE Id IN :processIds];
        
        //assemble a mapping of process ids to configurable strings
        Map<Id,String> processId2configurable = new Map<Id,String>();
        for (Process__c process : processes) processId2configurable.put(process.Id, process.Configurable__c);
        
        //we will do applicable chainsteps and configurations in tandem
        List<ChainStep__c> configuredChainSteps = new List<ChainStep__c>();
        List<SObject> configurations = new List<SObject>();
        
        //assemble applicable chainsteps and configurations
        for (ChainStep__c chainStep : chainSteps) {
            String configurable = processId2configurable.get(chainStep.Process__c);
            if (configurable != null) {
                SObject configuration = (SObject)Type.forName(configurable).newInstance();
                configuredChainSteps.add(chainStep);
                configurations.add(configuration);
            }
        }
        
        insert configurations;
        
        //reconcile the configuration ids back onto the chain steps
        for (Integer i = 0; i < configuredChainSteps.size(); i++) {
            ChainStep__c chainStep = configuredChainSteps[i];
            SObject configuration = configurations[i];
            chainStep.ConfigurationId__c = configuration.Id;
        }
    }
    
    /**
     * If a step has configuration, there is a one-to-one relationship.
     * ChainStepAfterInsert takes care of the creation of the configuration.
     * This trigger takes care of the deletion of the configuration.
     */
    private void deleteConfigurations() {
        Set<Id> chainStepIds = (new Map<Id,SObject>(this.sobjects)).keySet();
        Map<Id,ChainStep__c> id2step = new Map<Id,ChainStep__c>([SELECT id, Name, ConfigurationId__c FROM ChainStep__c WHERE Id IN :chainStepIds]);
        
        //prepare list of configuration ids
        List<Id> ids = new List<Id>();
        
        //enumerate chain steps to get configuration ids
        for (ChainStep__c chainStep : id2step.values()) {
            if (null == chainStep.ConfigurationId__c) continue;
            ids.add(chainStep.ConfigurationId__c);
        }
        
        //delete all the configuration records
        Database.delete(ids);
        Database.emptyRecycleBin(ids);
    } 
}