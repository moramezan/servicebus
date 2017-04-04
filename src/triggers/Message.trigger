trigger Message on Message__c (before insert, after insert, before update, after update, before delete, after delete, after undelete) {
    
    if (Trigger.isBefore && Trigger.isInsert) {
       
        new MessageSetModel(Trigger.new).onBeforeInsert();
    
    } else if (Trigger.isAfter && Trigger.isInsert) {
    
        new MessageSetModel(Trigger.new).onAfterInsert();
    
    } else if (Trigger.isBefore && Trigger.isUpdate) {
        
        new MessageSetModel(Trigger.new).onBeforeUpdate(Trigger.old);
    
    } else if (Trigger.isAfter && Trigger.isUpdate) {
        
        new MessageSetModel(Trigger.new).onAfterUpdate(Trigger.old);
    
    } else if (Trigger.isBefore && Trigger.isDelete) {
        
        new MessageSetModel(Trigger.old).onBeforeDelete();
    
    } else if (Trigger.isAfter && Trigger.isDelete) {
        
        new MessageSetModel(Trigger.old).onAfterDelete();
        
    } else if (Trigger.isAfter && Trigger.isUndelete) {
        
        new MessageSetModel(Trigger.new).onAfterUndelete();
        
    }
    
}