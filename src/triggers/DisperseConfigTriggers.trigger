/**
 * Generates a friendly description of the configured behaviour.
 */
trigger DisperseConfigTriggers on DisperseConfig__c (before insert, before update) {
    
    //affected disperse configs
    List<DisperseConfig__c> configs = Trigger.new;
    Set<Id> configIds = new Set<Id>();
    for (DisperseConfig__c config : configs) configIds.add(config.Id);
    
    //find any destination sequences
    List<DisperseDestination__c> destinations = [
        SELECT Id, DisperseConfig__c, Sequence__r.Name
        FROM DisperseDestination__c
        WHERE DisperseConfig__c IN :configIds
        ORDER BY Sequence__r.Name ASC
    ];
    
    //group them up by disperse config id
    Map<Id,List<String>> configId2sequenceNames = new Map<Id,List<String>>();
    for (DisperseDestination__c destination : destinations) {
        Id configId = destination.DisperseConfig__c;
        if (configId2sequenceNames.get(configId) == null) {
            //initialize lists
            configId2sequenceNames.put(configId, new List<String>());
        }
        
        List<String> sequenceNames = configId2sequenceNames.get(configId);
        sequenceNames.add(destination.Sequence__r.Name);
    }
    
    //put sequence name on each disperse config
    for (DisperseConfig__c config : configs) {
        List<String> sequenceNames = configId2sequenceNames.get(config.Id);
        if (sequenceNames == null || sequenceNames.isEmpty()) {
            config.Name = ('This step must be configured!').left(80);
        } else {
            config.Name = ('Copies the message to "' + String.join(sequenceNames, '", "') + '".').left(80);
        }
    }
    
    //upsert dml performed by itself

}