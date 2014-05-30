/**
 * Generates a friendly description of the configured behaviour.
 */
trigger PublishConfigurationTriggers on PublishConfiguration__c (before insert, before update) {
    
    //affected publish configurations
    List<PublishConfiguration__c> configs = Trigger.new;
    
    //find any event types published to
    Set<Id> eventTypeIds = new Set<Id>();
    for (PublishConfiguration__c config : configs) eventTypeIds.add(config.EventType__c);
    Map<Id,EventType__c> id2eventType = new Map<Id,EventType__c>([
        SELECT Id, Name
        FROM EventType__c
        WHERE Id IN :eventTypeIds
    ]);
    
    //put event type name on any publish configurations
    for (PublishConfiguration__c config : configs) {
        EventType__c eventType = id2eventType.get(config.EventType__c);
        if (eventType == null) {
            config.Name = ('This step must be configured!').left(80);
        } else {
            config.Name = ('Broadcasts the message to all sequences subscribed to "' + eventType.Name + '".').left(80);
        }
    }
    
    //upsert dml happens
}