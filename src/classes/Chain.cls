public class Chain extends SalesforceObject {

    public Chain(Chain__c chain) {
        super(chain);
    }
    
    public ChainSteps fetchSteps() {
        List<String> fields = new List<String>();
        
        //chainstep fields
        Set<String> chainStepFields = SObjectType.ChainStep__c.Fields.getMap().keySet();
        for (String chainStepField : SObjectType.ChainStep__c.Fields.getMap().keySet()) fields.add(chainStepField);
        
        //process fields
        Set<String> processFields = SObjectType.Process__c.Fields.getMap().keySet();
        for (String processField : SObjectType.Process__c.Fields.getMap().keySet()) fields.add(SObjectType.ChainStep__c.Fields.Process__c.RelationshipName + '.' + processField);
        
        String chainId = this.getSObject().Id;
        String orderBy = SObjectType.ChainStep__c.Fields.Sequence__c.Name;
        List<ChainStep__c> chainSteps = Database.query('SELECT ' + String.join(fields, ',') + ' FROM ChainStep__c WHERE Chain__c = :chainId ORDER BY ' + orderBy);
        
        //ConfigurationName field from related configs
        for (ChainStep__c chainStep : chainSteps) {
            Id configurationId = chainStep.ConfigurationId__c;
            if (null == configurationId) continue;
            String objectType = configurationId.getSObjectType().getDescribe().getName();
            SObject config = Database.query('SELECT Id, Name FROM ' + objectType + ' WHERE Id = :configurationId');
            String configurationName = (String)config.get('Name');
            chainStep.ConfigurationName__c = configurationName.left(80);
        }
        
        return new ChainSteps(chainSteps);
    }
    
    public ChainStep appendStep(Id processId) {
        ChainStep__c chainStep = new ChainStep__c(
            Chain__c = this.getSObject().Id,
            Process__c = processId
            //Sequence__c is automatic
        );
        
        insert chainStep;
        return new ChainStep(chainStep);
    }
    
    /**
     * If this chain contains no Terminate step, append one.
     * (Invoked by the user interface when viewing a Chain for the first time)
     */
    public void terminate() {
        Chain__c chain = (Chain__c)this.getSObject();
        
        Process__c terminateProcess = [
            SELECT Id
            FROM Process__c
            WHERE FullyQualifiedClassName__c = :Terminate.class.getName()
        ];
        
        try {
            ChainStep__c terminateStep = [
                SELECT Id
                FROM ChainStep__c
                WHERE Chain__c = :chain.Id AND Process__c = :terminateProcess.Id
            ];
        } catch (QueryException e) {
            //chain contains no terminate step
            this.appendStep(terminateProcess.Id);
        }
    }
    
    public ChainStep deleteStep(Id stepId) {
        //validate and perform the delete
        Chain__c chain = (Chain__c)this.getSObject();
        ChainStep__c chainStep = (ChainStep__c)SalesforceObject.getById(stepId);
        System.assert(chain.Id == chainStep.Chain__c, 'Cannot deleteStep from different chain ' + chain.Id + ' ' + chainStep.Chain__c);
        delete chainStep;
        
        //find the remaining chain steps
        List<ChainStep__c> stepsToReorder = [
            SELECT Id
            FROM ChainStep__c
            WHERE Chain__c = :chain.Id
            ORDER BY Sequence__c ASC
        ];
        
        //resequence them
        Integer sequence = 1;
        for (ChainStep__c step : stepsToReorder) step.Sequence__c = sequence++;
        update stepsToReorder;
        
        //hand back wrapped deleted step
        return new ChainStep(chainStep);
    }

}