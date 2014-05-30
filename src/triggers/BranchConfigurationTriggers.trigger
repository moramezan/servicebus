/**
 * Generates a friendly description of the configured behaviour.
 */
trigger BranchConfigurationTriggers on BranchConfiguration__c (before insert, before update) {
    
    //affected branch configurations
    List<BranchConfiguration__c> configs = Trigger.new;
    
    //find any sequences branched to
    Set<Id> sequenceIds = new Set<Id>();
    for (BranchConfiguration__c config : configs) sequenceIds.add(config.Sequence__c);
    Map<Id,Sequence__c> id2sequence = new Map<Id,Sequence__c>([
        SELECT Id, Name
        FROM Sequence__c
        WHERE Id IN :sequenceIds
    ]);
    
    //put sequence name on any branch configurations
    for (BranchConfiguration__c config : configs) {
        Sequence__c sequence = id2sequence.get(config.Sequence__c);
        if (sequence == null) {
            config.Name = ('This step must be configured!').left(80);
        } else {
            config.Name = ('Copies the message to sequence "' + sequence.Name + '".').left(80);
        }
    }
    
    //upsert dml happens
}