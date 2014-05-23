trigger StepTriggers on Step__c (before insert, after insert, before update, after update, before delete, after delete) {

    if (Trigger.isBefore && Trigger.isInsert) {
       
        new StepObjectSet(Trigger.new).onBeforeInsert();
    
    } else if (Trigger.isAfter && Trigger.isInsert) {
    
        new StepObjectSet(Trigger.new).onAfterInsert();
    
    } else if (Trigger.isBefore && Trigger.isUpdate) {
        
        new StepObjectSet(Trigger.new).onBeforeUpdate(Trigger.old);
    
    } else if (Trigger.isAfter && Trigger.isUpdate) {
        
        new StepObjectSet(Trigger.new).onAfterUpdate(Trigger.old);
    
    } else if (Trigger.isBefore && Trigger.isDelete) {
        
        new StepObjectSet(Trigger.old).onBeforeDelete();
    
    } else if (Trigger.isAfter && Trigger.isDelete) {
        
        new StepObjectSet(Trigger.old).onAfterDelete();
    }
}