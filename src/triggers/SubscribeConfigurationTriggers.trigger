/**
 * Generates a friendly description of the configured behaviour.
 */
trigger SubscribeConfigurationTriggers on SubscribeConfiguration__c (before insert, before update) {
    
    //affected subscribe configurations
    List<SubscribeConfiguration__c> configs = Trigger.new;
    
    //find any event types listened on
    Set<Id> eventTypeIds = new Set<Id>();
    for (SubscribeConfiguration__c config : configs) eventTypeIds.add(config.EventType__c);
    Map<Id,EventType__c> id2eventType = new Map<Id,EventType__c>([
        SELECT Id, Name
        FROM EventType__c
        WHERE Id IN :eventTypeIds
    ]);
    
    //put event type name on any publish configurations
    for (SubscribeConfiguration__c config : configs) {
        EventType__c eventType = id2eventType.get(config.EventType__c);
        if (eventType == null) {
            config.Name = ('This step must be configured!').left(80);
        } else {
            config.Name = ('Listens for any message published to "' + eventType.Name + '".').left(80);
        }
    }
    
    //upsert dml happens
}