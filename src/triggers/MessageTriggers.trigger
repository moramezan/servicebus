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
    
}