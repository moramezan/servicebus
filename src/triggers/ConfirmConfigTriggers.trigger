/**
 * Generates a friendly description of the configured behaviour.
 */
trigger ConfirmConfigTriggers on ConfirmConfig__c (before insert, before update) {
    
    //affected branch configs
    List<ConfirmConfig__c> configs = Trigger.new;
    
    //find any sequences branched to
    Set<Id> sequenceIds = new Set<Id>();
    for (ConfirmConfig__c config : configs) sequenceIds.add(config.DenySequence__c);
    Map<Id,Sequence__c> id2sequence = new Map<Id,Sequence__c>([
        SELECT Id, Name
        FROM Sequence__c
        WHERE Id IN :sequenceIds
    ]);
    
    //put sequence name on any branch configs
    for (ConfirmConfig__c config : configs) {
        Sequence__c sequence = id2sequence.get(config.DenySequence__c);
        if (sequence == null) {
            config.Name = ('Messages await confirmation, or are swallowed if denied.').left(80);
        } else {
            config.Name = ('Messages await confirmation, or jump to "' + sequence.Name + '" if denied.').left(80);
        }
    }
    
    //upsert dml happens
}