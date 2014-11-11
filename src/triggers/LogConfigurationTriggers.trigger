trigger LogConfigurationTriggers on LogConfiguration__c (before insert, before update) {
    
    
    //affected logConfigurations
    List<LogConfiguration__c > logConfigurations = Trigger.new;


    if (Trigger.isBefore && Trigger.isInsert) {
        
        new LogConfigurationObjectSet (Trigger.new).onBeforeInsert();
        
    } else if (Trigger.isAfter && Trigger.isInsert) {
        
        new LogConfigurationObjectSet (Trigger.new).onAfterInsert();
        
    } else if (Trigger.isBefore && Trigger.isUpdate) {
        
        new LogConfigurationObjectSet (Trigger.new).onBeforeUpdate(Trigger.old);
        
    } else if (Trigger.isAfter && Trigger.isUpdate) {
        
        new LogConfigurationObjectSet (Trigger.new).onAfterUpdate(Trigger.old);
        
    } else if (Trigger.isBefore && Trigger.isDelete) {
        
        new LogConfigurationObjectSet (Trigger.old).onBeforeDelete();
        
    } else if (Trigger.isAfter && Trigger.isDelete) {
        
        new LogConfigurationObjectSet (Trigger.old).onAfterDelete();
    }
}