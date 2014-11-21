/**
 * Generates a friendly description of the configured behaviour.
 */
trigger JumpConfigTriggers on JumpConfig__c (before insert, before update) {
    
    //affected jump configs
    List<JumpConfig__c> configs = Trigger.new;
    
    //find any sequences jump to
    Set<Id> sequenceIds = new Set<Id>();
    for (JumpConfig__c config : configs) sequenceIds.add(config.Sequence__c);
    Map<Id,Sequence__c> id2sequence = new Map<Id,Sequence__c>([
        SELECT Id, Name
        FROM Sequence__c
        WHERE Id IN :sequenceIds
    ]);
    
    //put sequence name on any jump configs
    for (JumpConfig__c config : configs) {
        Sequence__c sequence = id2sequence.get(config.Sequence__c);
        if (sequence == null) {
            config.Name = ('This step must be configured!').left(80);
        } else {
            config.Name = ('Diverts message to sequence "' + sequence.Name + '", never to return.').left(80);
        }
    }
    
    //upsert dml happens
}