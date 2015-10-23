public class SequenceSetModel extends ApexDomain.StandardSetModel {
    
    public class SequenceException extends Exception {}
    
    /**
     * True means a deleted sequence will trash draft steps and configs (discard).
     * False means only the sequence or 'handle' will be deleted itself (commit).
     * Default is true, because GUI deletes are always in the context of drafts.
     */
    static public Boolean IsDeleteCascaded = true;
    
    public SequenceSetModel(List<Sequence__c> sequences) {
        super(sequences);
    }
    
    static public void checkoutDraft() {
        
        Boolean hasSequences = ![SELECT Id FROM Sequence__c LIMIT 1].isEmpty();
        Boolean noLiveSteps = [SELECT Id FROM Step__c WHERE IsDraft__c = false LIMIT 1].isEmpty();
        Boolean hasDraftSteps = ![SELECT Id FROM Step__c WHERE IsDraft__c = true LIMIT 1].isEmpty();
        
        if (hasDraftSteps || hasSequences) {
            //failure, draft already exist
            throw new SequenceException('Already checked out.');
        }
        
        if (noLiveSteps) {
            //failure, nothing live exists
            throw new SequenceException('Nothing to checkout.');
        }
        
        Savepoint savepoint;
        try {
            savepoint = Database.setSavepoint();
            
            //find latest runnable version
            Decimal version = (Decimal)[
                SELECT Max(Version__c)
                FROM Step__c
                WHERE IsDraft__c = false
            ][0].get('expr0');
            
            //clone the steps
            List<Step__c> steps = [
                SELECT Name, ApexClassId__c, ApexClassName__c, ConfigId__c, ConfigName__c, Version__c, SequenceName__c, Position__c, IsDraft__c //TODO apexdomain all fields
                FROM Step__c
                WHERE Version__c = :version
            ].deepClone(); //TODO explicit args
            
            //increment as next draft version
            for (Step__c step : steps) {
                step.Version__c++;
                step.Name = step.Version__c + '#' + step.SequenceName__c + '#' + step.Position__c;
                step.IsDraft__c = true;
            }
            
            //new steps first
            insert steps;
            
            //new sequences second (to avoid inhibit)
            Set<Sequence__c> sequences = new Set<Sequence__c>();
            for (Step__c step : steps) sequences.add(new Sequence__c(Name = step.SequenceName__c));
            insert new List<Sequence__c>(sequences);
            
        } catch (Exception e) {
            Database.rollback(savepoint);
            throw e;
            
        }
    }
    
    /**
     * Locks in the draft version as a runnable version
     * (removes sequences, updates steps)
     */
    static public void commitDraft() {
        
        Boolean noDraftSteps = [SELECT Id FROM Step__c WHERE IsDraft__c = true LIMIT 1].isEmpty();
        Boolean noSequences = [SELECT Id FROM Sequence__c LIMIT 1].isEmpty();
        
        if (noDraftSteps || noSequences) {
            //failure, no draft to commit
            throw new SequenceException('Nothing to commit.');
        }
        
        Savepoint savepoint;
        try {
            savepoint = Database.setSavepoint();
            
            //find current draft
            List<Step__c> steps = [
                SELECT Id
                FROM Step__c
                WHERE IsDraft__c = true
            ];
            
            //mark steps as live
            for (Step__c step : steps) step.IsDraft__c = false;
            update steps;
            
            //remove sequences leaving steps intact
            IsDeleteCascaded = false;
            delete [SELECT Id FROM Sequence__c];
            
        } catch (Exception e) {
            Database.rollback(savepoint);
            throw e;
            
        }
    }
    
    /**
     * Trashes the draft version
     * (removes sequences and steps)
     */
    static public void discardDraft() {
        
        Boolean noDraftSteps = [SELECT Id FROM Step__c WHERE IsDraft__c = true LIMIT 1].isEmpty();
        Boolean noSequences = [SELECT Id FROM Sequence__c LIMIT 1].isEmpty();
        
        if (noDraftSteps && noSequences) {
            //failure, no draft to discard
            throw new SequenceException('Nothing to discard.');
        }
        
        Savepoint savepoint;
        try {
            savepoint = Database.setSavepoint();
            
            //trash everything
            IsDeleteCascaded = true;
            delete [SELECT Id FROM Sequence__c];
            
        } catch (Exception e) {
            Database.rollback(savepoint);
            throw new SequenceException('Cannot discard: ' + e.getMessage(), e);
            
        }
    }
    
    public override void onBeforeInsert() {
        this.inhibitInsertWithoutCheckout();
    }
    
    @TestVisible void inhibitInsertWithoutCheckout() {
        
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
        for (Sequence__c sequence : sequences) sequence.Name.addError('Checkout required first.');
    }
    
    public override void onBeforeDelete() {
        if (IsDeleteCascaded) this.destroyAllStepsAndConfigs();
    }
    
    public override void onAfterDelete() {
        //#1016 skip recycle bin
        List<Sequence__c> sequences = this.Records;
        Database.emptyRecycleBin(sequences);
    }
    
    /**
     * When deleting a SEQUENCE, we no longer have master-detail to delete the STEP,
     * so we cascade the delete ourselves manually, and take care of the configs too.
     */
    @TestVisible private void destroyAllStepsAndConfigs() {
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
                AND SequenceName__c IN :sequenceNames
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
            
        } catch (Exception e) {
            Database.rollback(savepoint);
            throw new SequenceException('Cannot destroy all steps and configs: ' + e.getMessage(), e);
        }
    }
}