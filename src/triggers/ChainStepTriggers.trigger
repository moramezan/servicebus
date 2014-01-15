trigger ChainStepTriggers on ChainStep__c (before insert, after insert, before update, after update, before delete, after delete) {

    if (Trigger.isBefore && Trigger.isInsert) {
       
        new ChainSteps(Trigger.new).onBeforeInsert();
    
    } else if (Trigger.isAfter && Trigger.isInsert) {
    
        new ChainSteps(Trigger.new).onAfterInsert();
    
    } else if (Trigger.isBefore && Trigger.isUpdate) {
        
        new ChainSteps(Trigger.new).onBeforeUpdate(Trigger.old);
    
    } else if (Trigger.isAfter && Trigger.isUpdate) {
        
        new ChainSteps(Trigger.new).onAfterUpdate(Trigger.old);
    
    } else if (Trigger.isBefore && Trigger.isDelete) {
        
        new ChainSteps(Trigger.old).onBeforeDelete();
    
    } else if (Trigger.isAfter && Trigger.isDelete) {
        
        new ChainSteps(Trigger.old).onAfterDelete();
    }
}