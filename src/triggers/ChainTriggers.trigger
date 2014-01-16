trigger ChainTriggers on Chain__c (before insert, after insert, before update, after update, before delete, after delete) {
    
    if (Trigger.isBefore && Trigger.isInsert) {
       
        new Chains(Trigger.new).onBeforeInsert();
    
    } else if (Trigger.isAfter && Trigger.isInsert) {
    
        new Chains(Trigger.new).onAfterInsert();
    
    } else if (Trigger.isBefore && Trigger.isUpdate) {
        
        new Chains(Trigger.new).onBeforeUpdate(Trigger.old);
    
    } else if (Trigger.isAfter && Trigger.isUpdate) {
        
        new Chains(Trigger.new).onAfterUpdate(Trigger.old);
    
    } else if (Trigger.isBefore && Trigger.isDelete) {
        
        new Chains(Trigger.old).onBeforeDelete();
    
    } else if (Trigger.isAfter && Trigger.isDelete) {
        
        new Chains(Trigger.old).onAfterDelete();
    }
}