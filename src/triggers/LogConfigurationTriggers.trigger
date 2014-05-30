/**
 * Generates a friendly description of the configured behaviour.
 */
trigger LogConfigurationTriggers on LogConfiguration__c (before insert, before update) {
    
    //affected log configurations
    List<LogConfiguration__c> configs = Trigger.new;
    
    //either or! if static identifier exists, null out dynamic identifier
    for (LogConfiguration__c config : configs) {
        if (config.StaticGroupIdentifier__c != null) {
            config.DynamicGroupIdentifier__c = null; //chooser field name
            config.DynamicGroupIdentifierObjectName__c = null; //chooser object name
        }
    }
    
    //put identifier name on any log configurations
    for (LogConfiguration__c config : configs) {
        if (config.StaticGroupIdentifier__c == null && config.DynamicGroupIdentifier__c == null) {
            config.Name = ('Creates a Log Group based on the name of this sequence.').left(80);
        } else if (config.DynamicGroupIdentifier__c != null) {
            config.Name = ('Creates a Log Group named by "' + config.DynamicGroupIdentifier__c + '" on the message data.').left(80);
        } else if (config.StaticGroupIdentifier__c != null) {
            config.Name = ('Creates a Log Group named "' + config.StaticGroupIdentifier__c + '".').left(80);
        }
    }
    
    //upsert dml happens
}