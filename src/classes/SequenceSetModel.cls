public class SequenceSetModel extends ApexDomain.StandardSetModel {
    
    public class SequenceException extends Exception {}
    
    public SequenceSetModel(List<Sequence__c> sequences) {
        super(sequences);
    }
    
    public override void onBeforeDelete() {
        this.destroyAllStepsAndConfigs();
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
                WHERE SequenceName__c IN :sequenceNames
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