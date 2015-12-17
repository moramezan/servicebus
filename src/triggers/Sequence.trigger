trigger Sequence on Sequence__c (before insert, after insert, before update, after update, before delete, after delete) {
    
    if (Trigger.isBefore && Trigger.isInsert) {
       
        new SequenceSetModel(Trigger.new).onBeforeInsert();
    
    } else if (Trigger.isAfter && Trigger.isInsert) {
    
        new SequenceSetModel(Trigger.new).onAfterInsert();
    
    } else if (Trigger.isBefore && Trigger.isUpdate) {
        
        new SequenceSetModel(Trigger.new).onBeforeUpdate(Trigger.old);
    
    } else if (Trigger.isAfter && Trigger.isUpdate) {
        
        new SequenceSetModel(Trigger.new).onAfterUpdate(Trigger.old);
    
    } else if (Trigger.isBefore && Trigger.isDelete) {
        
        new SequenceSetModel(Trigger.old).onBeforeDelete();
    
    } else if (Trigger.isAfter && Trigger.isDelete) {
        
        new SequenceSetModel(Trigger.old).onAfterDelete();
        
    } else if (Trigger.isAfter && Trigger.isUndelete) {
        
        new SequenceSetModel(Trigger.new).onAfterUndelete();
        
    }
}