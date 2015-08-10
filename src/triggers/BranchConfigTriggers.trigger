/**
 * Generates a friendly description of the configured behaviour.
 */
trigger BranchConfigTriggers on BranchConfig__c (before insert, before update) {
    
    //affected branch configs
    List<BranchConfig__c> configs = Trigger.new;
    
    //find any sequences branched to
    Set<Id> sequenceIds = new Set<Id>();
    for (BranchConfig__c config : configs) sequenceIds.add(config.Sequence__c);
    Map<Id,Sequence__c> id2sequence = new Map<Id,Sequence__c>([
        SELECT Id, Name
        FROM Sequence__c
        WHERE Id IN :sequenceIds
    ]);
    
    //put sequence name on any branch configs
    for (BranchConfig__c config : configs) {
        Sequence__c sequence = id2sequence.get(config.Sequence__c);
        if (sequence == null) {
            config.Name = ('This step must be configured. Seriously.').left(80);
        } else {
            config.Name = ('Copies the message to sequence "' + sequence.Name + '".').left(80);
        }
    }
    
    //upsert dml happens
}