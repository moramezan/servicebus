trigger AuditInitializerConfigTriggers on AuditInitializerConfig__c (before insert, before update) {
    
    if (Trigger.isBefore && Trigger.isInsert) {
        
        new AuditInitializerConfigSetModel (Trigger.new).onBeforeInsert();
        
    } else if (Trigger.isAfter && Trigger.isInsert) {
        
        new AuditInitializerConfigSetModel (Trigger.new).onAfterInsert();
        
    } else if (Trigger.isBefore && Trigger.isUpdate) {
        
        new AuditInitializerConfigSetModel (Trigger.new).onBeforeUpdate(Trigger.old);
        
    } else if (Trigger.isAfter && Trigger.isUpdate) {
        
        new AuditInitializerConfigSetModel (Trigger.new).onAfterUpdate(Trigger.old);
        
    } else if (Trigger.isBefore && Trigger.isDelete) {
        
        new AuditInitializerConfigSetModel (Trigger.old).onBeforeDelete();
        
    } else if (Trigger.isAfter && Trigger.isDelete) {
        
        new AuditInitializerConfigSetModel (Trigger.old).onAfterDelete();
    }
}