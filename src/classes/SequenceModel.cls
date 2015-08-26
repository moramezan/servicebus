public class SequenceModel extends ApexDomain.StandardModel {

    private Sequence__c sequence;
    
    /**
     * For advertising domain layer errors
     */
    public class SequenceException extends Exception {}
    
    /**
     * Privatize constructor to force use of fromName() or fromId()
     */
    private SequenceModel(Sequence__c sequence) {
        super(sequence);
        this.sequence = sequence;
    }
    
    /**
     * Given a sequence id, loads a model with all fields.
     *
     * @param sequenceId
     * @return domain model of sequence
     */
    static public SequenceModel fromId(Id sequenceId) {
        Sequence__c sequence = (Sequence__c)ApexDomain.getById(sequenceId);
        return new SequenceModel(sequence);
    }
    
    /**
     * Given a sequence name, loads a model with all fields.
     *
     * @param sequenceName
     * @return domain model of sequence
     */
    static public SequenceModel fromName(String sequenceName) {
        Sequence__c sequence = [SELECT Id FROM Sequence__c WHERE Name = :sequenceName];
        return fromId(sequence.Id);
    }
    
    /**
     * Find the steps from this sequence
     */
    public StepSetModel stepSetModel() {
        return StepSetModel.forSequence(this.Sequence.Name);
    }
    
    /**
     * Appends one step to the end of a sequence,
     * normally it will appear after the Terminate.
     * PROD scenarios append both class name and id.
     *
     * @param reflector
     * @return the appended step
     */
    public Step__c appendStep(Id apexClassId) {
        ApexClass apexClass = [
            SELECT Id, NamespacePrefix, Name
            FROM ApexClass
            WHERE Id = :apexClassId
        ];
        
        Type reflector = Type.forName(apexClass.NamespacePrefix, apexClass.Name);
        Step__c step = this.appendStep(reflector);
        step.ApexClassId__c = apexClassId;
        update step;
        
        return step;
    }
    
    /**
     * Injects a test message to this sequence
     * carrying just the Organization Id.
     *
     * @return the queueable job id
     */
    public Id enqueueTestMessage() {
        Job.AllowRoute = true; //#999#issuecomment-133751700
        Map<String,Object> event = new Map<String,Object>{
            'Route' => this.Sequence.Name + '#0',
            'RecordId' => UserInfo.getOrganizationId()
        };
        Job j = new Job(event);
        Id jobId = System.enqueueJob(j);
        return jobId;
    }
    
    /**
     * TEST scenarios can append inner classes.
     */
    @TestVisible private Step__c appendStep(Type reflector) {
        if (!SObjectType.Step__c.Createable) throw new ApexDomain.CrudException('!SObjectType.Step__c.Createable');
        Savepoint sp = Database.setSavepoint();
        try {
            ApexClassModel model = new ApexClassModel(reflector);
            Integer position = [SELECT COUNT() FROM Step__c WHERE SequenceName__c = :this.sequence.Name] + 1;
            
            Step__c step = new Step__c(
                Name = this.sequence.Name + '#' + position,
                SequenceName__c = this.sequence.Name,
                ApexClassId__c = null, //see upstairs
                ApexClassName__c = reflector.getName(),
                Position__c = position
            );
            
            insert step;
            return Step__c.getValues(step.Name);
        } catch (Exception e) {
            Database.rollback(sp);
            throw new SequenceException('Could not append step "' + reflector + '"', e);
        }
    }
    
    /**
     * If this sequence contains no Terminate step, append one.
     * (Invoked by the user interface when viewing a Sequence for the first time)
     */
    public void terminateIfNeeded() {
        try {
            Step__c terminateStep = [
                SELECT Name
                FROM Step__c
                WHERE SequenceName__c = :this.sequence.Name AND ApexClassName__c = :Terminate.class.getName()
            ];
        } catch (QueryException e) {
            //sequence contains no terminate step
            ApexClass apexClass = [
                SELECT Id, NamespacePrefix, Name
                FROM ApexClass
                WHERE NamespacePrefix = :NamespaceSetting__c.getOrgDefaults().Prefix__c
                AND Name = 'Terminate'
            ];
            
            //TODO add namespace prefix safety
            this.appendStep(apexClass.Id);
        }
    }
    
    /**
     * Destroys a step within a sequence, including any
     * related StepConfig, and re-orders the other steps.
     *
     * @param stepName or route
     */
    public void destroyStep(String stepName) {
        Savepoint sp = Database.setSavepoint();
        try {
            if (!SObjectType.Step__c.Deletable) throw new ApexDomain.CrudException('!SObjectType.Step__c.Deletable');
            if (!SObjectType.Step__c.Fields.Position__c.Updateable) throw new ApexDomain.FlsException('!SObjectType.Step__c.Fields.Position__c.Updateable');
            
            Step__c stepToDelete = Step__c.getValues(stepName);
            
            //perform the delete
            delete stepToDelete;
            
            //any config to delete
            if (stepToDelete.ConfigId__c != null) Database.delete(stepToDelete.ConfigId__c);
            
            //find the remaining steps
            List<Step__c> stepsToReorder = [
                SELECT Name
                FROM Step__c
                WHERE SequenceName__c = :this.sequence.Name
                ORDER BY Position__c ASC
            ];
            
            //custom settings not smart enough to recognize uniqueness in bulk update
            //https://developer.salesforce.com/forums/ForumsMain?id=906F00000008zF5IAI
            //so we have to make them unique first so that we can overwrite them second
            for (Step__c stepToReorder : stepsToReorder) stepToReorder.Name = EncodingUtil.base64encode(Crypto.generateAesKey(192));
            update stepsToReorder;
            
            //reposition them all
            Integer position = 1;
            for (Step__c stepToReorder : stepsToReorder) {
                stepToReorder.Name = this.sequence.Name + '#' + position;
                stepToReorder.Position__c = position;
                position++;
            }
            
            update stepsToReorder;
        } catch (Exception e) {
            Database.rollback(sp);
            throw new SequenceException('Could not destroy step "' + stepName + '"', e);
        }
    }
    
    /**
     * #768 this is used to indicate there is work processing
     * by displaying a twirly alongside the count of messages
     * that are flowing through this sequence.
     */
    public Integer countRoutedMessages() {
        Integer total = 0;
        
        //#954 looped aggregate query to count > 50000 safely
        for (AggregateResult result : [
            SELECT COUNT(Id) total
            FROM Message__c
            WHERE Route__c LIKE :this.Sequence.Name + '#%'
            AND Status__c != 'Completed'
            AND Exception__c = null
            GROUP BY Route__c
        ]) total += (Integer)result.get('total');
        
        return total;
    }
    
}