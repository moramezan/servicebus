/**
 * Generates a friendly description of the configured behaviour.
 */
trigger PublishConfigTriggers on PublishConfig__c (before insert, before update) {
    
    //affected publish configs
    List<PublishConfig__c> configs = Trigger.new;
    
    //find any event types published to
    Set<Id> eventTypeIds = new Set<Id>();
    for (PublishConfig__c config : configs) eventTypeIds.add(config.EventType__c);
    Map<Id,EventType__c> id2eventType = new Map<Id,EventType__c>([
        SELECT Id, Name
        FROM EventType__c
        WHERE Id IN :eventTypeIds
    ]);
    
    //put event type name on any publish configs
    for (PublishConfig__c config : configs) {
        EventType__c eventType = id2eventType.get(config.EventType__c);
        if (eventType == null) {
            config.Name = ('This step must be configured. Seriously.').left(80);
        } else {
            config.Name = ('Broadcasts the message to all sequences subscribed to "' + eventType.Name + '".').left(80);
        }
    }
    
    //upsert dml happens
}