/**
 * Generates a friendly description of the configured behaviour.
 */
trigger MarkConfigTriggers on MarkConfig__c (before insert, before update) {
    
    //affected mark configs
    List<MarkConfig__c> configs = Trigger.new;
    
    //put name on any branch configs
    for (MarkConfig__c config : configs) {
        config.Name = 'Marks the message with a correlation key, for splitting into a collection.';
    }
    
    //upsert dml happens
}