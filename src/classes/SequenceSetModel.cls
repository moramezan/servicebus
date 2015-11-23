public class SequenceSetModel extends ApexDomain.StandardSetModel {
    
    public class ModelException extends Exception {}
    
    /**
     * True means a deleted sequence will trash draft steps and configs (discard).
     * False means only the sequence or 'handle' will be deleted itself (commit).
     * Default is true, because GUI deletes are always in the context of drafts.
     */
    static public Boolean IsDeleteCascaded = true;
    
    @TestVisible List<Sequence__c> sequences;
    
    public SequenceSetModel(List<Sequence__c> sequences) {
        super(sequences);
        this.sequences = sequences;
    }
    
    override public void onAfterInsert() {
        this.enforceUniqueName();
        this.enforceValidName();
    }

    override public void onAfterUpdate(List<Sobject> oldRecords) {
        this.enforceFixedName(oldRecords);
    }
    
    /**
     * Per #997 we do this in a trigger, because
     * admins could just disable validation rules.
     */
    public void enforceUniqueName() {
        
        //list of
        Map<String,Sequence__c> name2sequence = new Map<String,Sequence__c>();
        for (Sequence__c sequence : this.sequences) name2sequence.put(sequence.Name, sequence);
        
        //count existing sequences
        List<AggregateResult> results = [
            SELECT Name, COUNT(Id) total
            FROM Sequence__c
            WHERE Name IN :name2sequence.keySet()
            GROUP BY Name
        ];
        
        //check against each one
        for (AggregateResult result : results) {
            Integer total = (Integer)result.get('total');
            if (total == 1) continue;
            
            String name = (String)result.get('Name');
            name2sequence.get(name).Name.addError('Name must be unique.');
        }
    }
    
    /**
     * Per #1099 we dont want long/# names to break
     */
    public void enforceValidName() {
        
        for (Sequence__c sequence : this.sequences) {
            if (sequence.Name.length() > 30) sequence.Name.addError('Name must not exceed 30 characters.');
            if (sequence.Name.contains('#')) sequence.Name.addError('Name must not contain # character.');
        }
        
    }
    
    /**
     * Per #997 we do this in a trigger, because
     * admins could just disable validation rules.
     */
    public void enforceFixedName(List<Sequence__c> oldSequences) {
        for (Integer i = 0; i < oldSequences.size(); i++) {
            Sequence__c oldSequence = oldSequences[i];
            Sequence__c newSequence = this.sequences[i];
            if (oldSequence.Name == newSequence.Name) continue;
            newSequence.Name.addError('Name cannot be changed.');
        }
    }
    
    /**
     * Finds integral draft version number
     * May be NULL if there is no draft!
     */
    static public Integer draftVersion() {
        return Integer.valueOf([
            SELECT AVG(Version__c)
            FROM Step__c
            WHERE IsDraft__c = true
        ][0].get('expr0'));
    }
    
    /**
     * Finds integral max version number
     * May be NULL if there is no max!
     */
    static public Integer latestVersion() {
        return Integer.valueOf([
            SELECT MAX(Version__c)
            FROM Step__c
            WHERE IsDraft__c = false
        ][0].get('expr0'));
    }
    
    /**
     * Cursor for current draft version
     */
    static public Database.QueryLocator locateDraftSteps() {
        return Database.getQueryLocator([
            SELECT Id, Name
            FROM Step__c
            WHERE IsDraft__c = true
            ORDER BY Sequence__c ASC, Position__c ASC
        ]);
    }
    
    /**
     * Cursor for given live version
     */
    static public Database.QueryLocator locateLiveSteps() {
        //find current running version
        return Database.getQueryLocator([
            SELECT Id, Name
            FROM Step__c
            WHERE Version__c = :BrokerSetting__c.getOrgDefaults().Version__c.intValue()
            ORDER BY Sequence__c ASC, Position__c ASC
        ]);
    }
    
    /**
     * Starts the "checkout draft version" process
     * which clones the latest version and increments.
     */
    static public Id checkoutDraft() {
        
        Boolean hasSequences = ![SELECT Id FROM Sequence__c LIMIT 1].isEmpty();
        Boolean noLiveSteps = [SELECT Id FROM Step__c WHERE IsDraft__c = false LIMIT 1].isEmpty();
        Boolean hasDraftSteps = ![SELECT Id FROM Step__c WHERE IsDraft__c = true LIMIT 1].isEmpty();
        
        if (hasDraftSteps || hasSequences) {
            //failure, draft already exist
            throw new ModelException('Already checked out.');
        }
        
        if (noLiveSteps) {
            //failure, nothing live exists
            throw new ModelException('Nothing to checkout.');
        }
        
        //start the job
        Database.Batchable<Sobject> batch = new SequenceCheckoutExtension();
        Id asyncApexJobId = Database.executeBatch(batch, 1);
        return asyncApexJobId;
    }
    
    /**
     * To finish the draft checkout process
     * we expose all the sequences as handles.
     */
    static public void showSequences() {
        
        Boolean noDraftSteps = [SELECT Id FROM Step__c WHERE IsDraft__c = true LIMIT 1].isEmpty();
        Boolean hasSequences = ![SELECT Id FROM Sequence__c LIMIT 1].isEmpty();
        
        if (hasSequences) {
            //failure, already showing
            throw new ModelException('Already showing sequences.');
        }
        
        if (noDraftSteps) {
            //failure, nothing draft exists
            throw new ModelException('Nothing to show.');
        }
        
        //find draft steps
        List<Step__c> steps = [
            SELECT Sequence__c
            FROM Step__c
            WHERE IsDraft__c = true
        ];
        
        //new sequences second (to avoid inhibit)
        Set<Sequence__c> sequences = new Set<Sequence__c>();
        for (Step__c step : steps) sequences.add(new Sequence__c(Name = step.Sequence__c));
        insert new List<Sequence__c>(sequences);
    }
    
    /**
     * Starts the "commit new version" process which
     * locks in the draft steps as a runnable version.
     */
    static public Id commitDraft() {
        
        Boolean noDraftSteps = [SELECT Id FROM Step__c WHERE IsDraft__c = true LIMIT 1].isEmpty();
        Boolean noSequences = [SELECT Id FROM Sequence__c LIMIT 1].isEmpty();
        
        if (noDraftSteps || noSequences) {
            //failure, no draft to commit
            throw new ModelException('Nothing to commit.');
        }
        
        //start the job
        Database.Batchable<Sobject> batch = new SequenceCommitExtension();
        Id asyncApexJobId = Database.executeBatch(batch, 1);
        return asyncApexJobId;
    }
    
    /**
     * To finish the batch commit (or discard) process
     * we trash the sequences which acted as handles.
     */
    static public void hideSequences() {
        
        Boolean noSequences = [SELECT Id FROM Sequence__c LIMIT 1].isEmpty();
        
        if (noSequences) {
            //failure, already showing
            throw new ModelException('Already hiding sequences.');
        }
        
        //leave steps alone (especially for commit!)
        IsDeleteCascaded = false;
        delete [SELECT Id FROM Sequence__c LIMIT 10000]; //checkmarx
    }
    
    /**
     * Starts the "discard draft version" process
     * which trashes the draft sequences AND steps.
     */
    static public Id discardDraft() {
        
        Boolean noDraftSteps = [SELECT Id FROM Step__c WHERE IsDraft__c = true LIMIT 1].isEmpty();
        Boolean noSequences = [SELECT Id FROM Sequence__c LIMIT 1].isEmpty();
        
        if (noDraftSteps && noSequences) {
            //failure, no draft to discard
            throw new ModelException('Nothing to discard.');
        }
        
        //start the job
        Database.Batchable<Sobject> batch = new SequenceDiscardExtension();
        Id asyncApexJobId = Database.executeBatch(batch, 1);
        return asyncApexJobId;
    }
    
    public override void onBeforeInsert() {
        this.inhibitInsertWithoutCheckout();
    }
    
    /**
     * New sequences are only createable
     * when there is a draft version.
     * (and FIRST ever sequence)
     */
    public void inhibitInsertWithoutCheckout() {
        
        Boolean noLiveSteps = [SELECT Id FROM Step__c WHERE IsDraft__c = false LIMIT 1].isEmpty();
        Boolean hasDraftSteps = ![SELECT Id FROM Step__c WHERE IsDraft__c = true LIMIT 1].isEmpty();
        
        if (noLiveSteps) {
            //success, permit insert for first ever sequence
            return;
        }
        
        if (hasDraftSteps) {
            //success, permit insert as draft is checked out
            return;
        }
        
        //failure, checkout first
        List<Sequence__c> sequences = this.Records;
        for (Sequence__c sequence : sequences) sequence.addError('Checkout required first.');
    }
    
    /**
     * GUI sequence delete will
     * trash the draft steps too.
     */
    public override void onBeforeDelete() {
        if (IsDeleteCascaded) this.destroyAllStepsAndConfigs();
    }
    
    /**
     * Prevent undelete, that would mess
     * with the checkout mechanism.
     */
    public override void onAfterDelete() {
        //#1016 skip recycle bin
        List<Sequence__c> sequences = this.Records;
        Database.emptyRecycleBin(sequences);
    }
    
    /**
     * When deleting a SEQUENCE, we no longer have master-detail to delete the STEP,
     * so we cascade the delete ourselves manually, and take care of the configs too.
     */
    @TestVisible void destroyAllStepsAndConfigs() {
        Savepoint savepoint = Database.setSavepoint();
        try {
            //query sequences
            List<Sequence__c> sequencesToDelete = [
                SELECT Id, Name
                FROM Sequence__c
                WHERE Id IN :this.keySet()
            ];
            
            //prepare sequence names
            Set<String> sequenceNames = new Set<String>();
            for (Sequence__c sequence : sequencesToDelete) sequenceNames.add(sequence.Name);
            
            //query steps
            List<Step__c> stepsToDelete = [
                SELECT Id, ConfigId__c
                FROM Step__c
                WHERE IsDraft__c = true
                AND Sequence__c IN :sequenceNames
            ];
            
            //prepare config ids
            List<Id> configsToDelete = new List<Id>();
            for (Step__c step : stepsToDelete) {
                if (step.ConfigId__c == null) continue;
                configsToDelete.add(step.ConfigId__c);
            }
            
            Database.delete(stepsToDelete, false);
            Database.delete(configsToDelete, false);
            
            //#1016 skip recycle bin
            if (!stepsToDelete.isEmpty()) Database.emptyRecycleBin(stepsToDelete);
            if (!configsToDelete.isEmpty()) Database.emptyRecycleBin(configsToDelete);
            
        } catch (DmlException e) {
            Database.rollback(savepoint);
            throw new ModelException('Cannot destroy all steps and configs: ' + e.getMessage(), e);
        }
    }
}