trigger AuditInitializerConfigTriggers on AuditInitializerConfig__c (before insert, before update) {
    
    if (Trigger.isBefore && Trigger.isInsert) {
        
        new AuditInitializerConfigObjectSet (Trigger.new).onBeforeInsert();
        
    } else if (Trigger.isAfter && Trigger.isInsert) {
        
        new AuditInitializerConfigObjectSet (Trigger.new).onAfterInsert();
        
    } else if (Trigger.isBefore && Trigger.isUpdate) {
        
        new AuditInitializerConfigObjectSet (Trigger.new).onBeforeUpdate(Trigger.old);
        
    } else if (Trigger.isAfter && Trigger.isUpdate) {
        
        new AuditInitializerConfigObjectSet (Trigger.new).onAfterUpdate(Trigger.old);
        
    } else if (Trigger.isBefore && Trigger.isDelete) {
        
        new AuditInitializerConfigObjectSet (Trigger.old).onBeforeDelete();
        
    } else if (Trigger.isAfter && Trigger.isDelete) {
        
        new AuditInitializerConfigObjectSet (Trigger.old).onAfterDelete();
    }
}