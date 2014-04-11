trigger ScheduleConfigurationTriggers on ScheduleConfiguration__c (before insert, after insert, before update, after update, before delete, after delete) {
    
    if (Trigger.isBefore && Trigger.isInsert) {
       
        new ScheduleConfigurationSet(Trigger.new).onBeforeInsert();
    
    } else if (Trigger.isAfter && Trigger.isInsert) {
    
        new ScheduleConfigurationSet(Trigger.new).onAfterInsert();
    
    } else if (Trigger.isBefore && Trigger.isUpdate) {
        
        new ScheduleConfigurationSet(Trigger.new).onBeforeUpdate(Trigger.old);
    
    } else if (Trigger.isAfter && Trigger.isUpdate) {
        
        new ScheduleConfigurationSet(Trigger.new).onAfterUpdate(Trigger.old);
    
    } else if (Trigger.isBefore && Trigger.isDelete) {
        
        new ScheduleConfigurationSet(Trigger.old).onBeforeDelete();
    
    } else if (Trigger.isAfter && Trigger.isDelete) {
        
        new ScheduleConfigurationSet(Trigger.old).onAfterDelete();
    }
}