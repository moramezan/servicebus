public with sharing class SequenceSetModel extends ApexDomain.StandardSetModel {
    
    public List<Sequence__c> sequences;
    
    public SequenceSetModel(List<Sequence__c> sequences) {
        super(sequences);
        this.sequences = sequences;
    }
    
    public override void onBeforeDelete() {
        this.destroyAllStepsAndConfigs();
    }
    
    /**
     * When deleting a SEQUENCE, we no longer have master-detail to delete the STEP,
     * so we cascade the delete ourselves manually, and take care of the configs too.
     */
    @TestVisible private void destroyAllStepsAndConfigs() {
        //prepare sequence names
        Set<String> sequenceNames = new Set<String>();
        for (Sequence__c sequence : this.sequences) sequenceNames.add(sequence.Name);
        
        List<Step__c> stepsToDelete = [
            SELECT Id, ConfigId__c
            FROM Step__c
            WHERE SequenceName__c IN :sequenceNames
        ];
        
        //perform the step delete
        delete stepsToDelete;
        
        //prepare any configs to delete
        List<Id> configIds = new List<Id>();
        for (Step__c stepToDelete : stepsToDelete) if (stepToDelete.ConfigId__c != null) configIds.add(stepToDelete.ConfigId__c);
        
        //perform the config delete
        Database.delete(configIds);
    }
}