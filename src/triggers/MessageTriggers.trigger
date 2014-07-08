/**
 * Use this hook to react to messages that encountered errors during processing.
 * For example, we formerly might have sent an email to the EDA Orchestrator.
 */
trigger MessageTriggers on Message__c (before insert) {
    
    //affected messages
    List<Message__c> messages = Trigger.new;

    for (Message__c message : messages) {
        if (message.Exception__c != null) {
            //houston we have a problem
        }
    }
    
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