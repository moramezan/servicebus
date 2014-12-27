trigger MessageTriggers on Message__c (before insert, after insert, before update, after update, before delete, after delete, after undelete) {
    
    if (Trigger.isBefore && Trigger.isInsert) {
       
        new MessageObjectSet(Trigger.new).onBeforeInsert();
    
    } else if (Trigger.isAfter && Trigger.isInsert) {
    
        new MessageObjectSet(Trigger.new).onAfterInsert();
    
    } else if (Trigger.isBefore && Trigger.isUpdate) {
        
        new MessageObjectSet(Trigger.new).onBeforeUpdate(Trigger.old);
    
    } else if (Trigger.isAfter && Trigger.isUpdate) {
        
        new MessageObjectSet(Trigger.new).onAfterUpdate(Trigger.old);
    
    } else if (Trigger.isBefore && Trigger.isDelete) {
        
        new MessageObjectSet(Trigger.old).onBeforeDelete();
    
    } else if (Trigger.isAfter && Trigger.isDelete) {
        
        new MessageObjectSet(Trigger.old).onAfterDelete();
    }
    
}