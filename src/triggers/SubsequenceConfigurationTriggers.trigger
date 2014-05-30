/**
 * Generates a friendly description of the configured behaviour.
 */
trigger SubsequenceConfigurationTriggers on SubsequenceConfiguration__c (before insert, before update) {
    
    //affected subsequence configurations
    List<SubsequenceConfiguration__c> configs = Trigger.new;
    
    //find any sequences boomeranged to
    Set<Id> sequenceIds = new Set<Id>();
    for (SubsequenceConfiguration__c config : configs) sequenceIds.add(config.Sequence__c);
    Map<Id,Sequence__c> id2sequence = new Map<Id,Sequence__c>([
        SELECT Id, Name
        FROM Sequence__c
        WHERE Id IN :sequenceIds
    ]);
    
    //put sequence name on any subsequence configurations
    for (SubsequenceConfiguration__c config : configs) {
        Sequence__c sequence = id2sequence.get(config.Sequence__c);
        if (sequence == null) {
            config.Name = ('This step must be configured!').left(80);
        } else {
            config.Name = ('Diverts message to sequence "' + sequence.Name + '", then returns to the next step.').left(80);
        }
    }
    
    //upsert dml happens
}