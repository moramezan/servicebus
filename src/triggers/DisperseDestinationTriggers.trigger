trigger DisperseDestinationTriggers on DisperseDestination__c (after insert, after update, after delete) {
    
    //genericize trigger for upserts and deletes
    List<DisperseDestination__c> destinations = Trigger.new != null ? Trigger.new : Trigger.old;
    
    //find all configs
    Set<DisperseConfig__c> configs = new Set<DisperseConfig__c>();
    for (DisperseDestination__c destination : destinations) {
        DisperseConfig__c config = new DisperseConfig__c(Id = destination.DisperseConfig__c);
        configs.add(config);
    }
    
    //fire their triggers to update their names
    update new List<DisperseConfig__c>(configs);
}