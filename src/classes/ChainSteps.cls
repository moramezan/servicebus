public class ChainSteps extends SObjects {
    
    public ChainSteps(List<ChainStep__c> sobjects) {
        super(sobjects);
    }
       

    /**
     * If a step's process has configuration, we need to insert the configuration at the same
     * time as the step. (We used to do this when the user attempted to view the configuration
     * for the first time, but that does DML from a Visualforce action and fails security review.)
     */
    public override void  onAfterInsert() {
        //re-query to get configs
        Set<Id> chainStepIds = (new Map<Id,SObject>(this.sobjects)).keySet();
        Map<Id,ChainStep__c> id2step = new Map<Id,ChainStep__c>([SELECT Process__r.Configurable__c, Process__r.Name FROM ChainStep__c WHERE Id IN :chainStepIds]);
        

        //create configs
        Map<Id,SObject> id2config = new Map<Id,SObject>();
        
        for (ChainStep__c chainStep : (List<ChainStep__c>) id2step.values()) {
            String edaConfigurable = chainStep.Process__r.Configurable__c;
            if (String.isBlank(edaConfigurable)) continue;
            Type configurableObject = Type.forName(edaConfigurable);
            SObject configuration = (SObject)configurableObject.newInstance();
            id2config.put(chainStep.Id, configuration);
        }
        
        insert id2config.values();
        
        //create back reference to config
        for (Id chainId : id2config.keySet()) {
            SObject config = id2config.get(chainId);
            ChainStep__c chainStep = id2step.get(chainId);
            chainStep.Configuration__c = config.Id;
        }
        
        //update chainsteps
        update id2step.values();
    } 
     

    /**
     * If a step has configuration, there is a one-to-one relationship.
     * ChainStepAfterInsert takes care of the creation of the configuration.
     * This trigger takes care of the deletion of the configuration.
     */
    public override void  onBeforeDelete() {
       Set<Id> chainStepIds = (new Map<Id,SObject>(this.sobjects)).keySet();
       Map<Id,ChainStep__c> id2step = new Map<Id,ChainStep__c>([SELECT id, Name, Configuration__c FROM ChainStep__c WHERE Id IN :chainStepIds]);
        
        //prepare list of configuration ids
        List<Id> ids = new List<Id>();
        
        //enumerate chain steps to get configuration ids
        for (ChainStep__c chainStep : id2step.values()) {
            if (null == chainStep.Configuration__c) continue;
            ids.add(chainStep.Configuration__c);
        }
        
        //delete all the configuration records
        Database.delete(ids);
    } 
}