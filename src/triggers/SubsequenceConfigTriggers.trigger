/**
 * Generates a friendly description of the configured behaviour.
 */
trigger SubsequenceConfigTriggers on SubsequenceConfig__c (before insert, before update) {
    
    //affected subsequence configs
    List<SubsequenceConfig__c> configs = Trigger.new;
    
    //find any sequences boomeranged to
    Set<Id> sequenceIds = new Set<Id>();
    for (SubsequenceConfig__c config : configs) sequenceIds.add(config.Sequence__c);
    Map<Id,Sequence__c> id2sequence = new Map<Id,Sequence__c>([
        SELECT Id, Name
        FROM Sequence__c
        WHERE Id IN :sequenceIds
    ]);
    
    //put sequence name on any subsequence configs
    for (SubsequenceConfig__c config : configs) {
        Sequence__c sequence = id2sequence.get(config.Sequence__c);
        if (sequence == null) {
            config.Name = ('This step must be configured. Seriously.').left(80);
        } else {
            config.Name = ('Diverts message to sequence "' + sequence.Name + '", then returns to the next step.').left(80);
        }
    }
    
    //upsert dml happens
}