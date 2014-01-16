trigger PersistentDataTriggers on PersistentData__c (before insert, after insert, before update, after update, before delete, after delete) {
    
    if (Trigger.isBefore && Trigger.isInsert) {
       
        new PersistentDatas(Trigger.new).onBeforeInsert();
    
    } else if (Trigger.isAfter && Trigger.isInsert) {
    
        new PersistentDatas(Trigger.new).onAfterInsert();
    
    } else if (Trigger.isBefore && Trigger.isUpdate) {
        
        new PersistentDatas(Trigger.new).onBeforeUpdate(Trigger.old);
    
    } else if (Trigger.isAfter && Trigger.isUpdate) {
        
        new PersistentDatas(Trigger.new).onAfterUpdate(Trigger.old);
    
    } else if (Trigger.isBefore && Trigger.isDelete) {
        
        new PersistentDatas(Trigger.old).onBeforeDelete();
    
    } else if (Trigger.isAfter && Trigger.isDelete) {
        
        new PersistentDatas(Trigger.old).onAfterDelete();
    }
}