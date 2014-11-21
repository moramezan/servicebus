trigger LogConfigTriggers on LogConfig__c (before insert, before update) {
    
    
    //affected logConfigs
    List<LogConfig__c > logConfigs = Trigger.new;


    if (Trigger.isBefore && Trigger.isInsert) {
        
        new LogConfigObjectSet (Trigger.new).onBeforeInsert();
        
    } else if (Trigger.isAfter && Trigger.isInsert) {
        
        new LogConfigObjectSet (Trigger.new).onAfterInsert();
        
    } else if (Trigger.isBefore && Trigger.isUpdate) {
        
        new LogConfigObjectSet (Trigger.new).onBeforeUpdate(Trigger.old);
        
    } else if (Trigger.isAfter && Trigger.isUpdate) {
        
        new LogConfigObjectSet (Trigger.new).onAfterUpdate(Trigger.old);
        
    } else if (Trigger.isBefore && Trigger.isDelete) {
        
        new LogConfigObjectSet (Trigger.old).onBeforeDelete();
        
    } else if (Trigger.isAfter && Trigger.isDelete) {
        
        new LogConfigObjectSet (Trigger.old).onAfterDelete();
    }
}