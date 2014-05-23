trigger SequenceTriggers on Sequence__c (before insert, after insert, before update, after update, before delete, after delete) {
    
    if (Trigger.isBefore && Trigger.isInsert) {
       
        new SequenceObjectSet(Trigger.new).onBeforeInsert();
    
    } else if (Trigger.isAfter && Trigger.isInsert) {
    
        new SequenceObjectSet(Trigger.new).onAfterInsert();
    
    } else if (Trigger.isBefore && Trigger.isUpdate) {
        
        new SequenceObjectSet(Trigger.new).onBeforeUpdate(Trigger.old);
    
    } else if (Trigger.isAfter && Trigger.isUpdate) {
        
        new SequenceObjectSet(Trigger.new).onAfterUpdate(Trigger.old);
    
    } else if (Trigger.isBefore && Trigger.isDelete) {
        
        new SequenceObjectSet(Trigger.old).onBeforeDelete();
    
    } else if (Trigger.isAfter && Trigger.isDelete) {
        
        new SequenceObjectSet(Trigger.old).onAfterDelete();
    }
}