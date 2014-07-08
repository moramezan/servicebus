public with sharing class MessageObjectSet extends SalesforceObjectSet {
    
    @TestVisible static private Integer MaxCompletedMessages = 5000;
    
    public MessageObjectSet(List<Message__c> messages) {
        super(messages);
    }
    
    override public void onBeforeInsert() {
        //find completed messages kicking around
        List<Message__c> persistedMessages = [
            SELECT Id
            FROM Message__c
            WHERE Status__c = 'Completed'
            ORDER BY CreatedDate ASC
            LIMIT :MaxCompletedMessages
        ];
        
        if (persistedMessages.size() < MaxCompletedMessages) {
            //do nothing unless there are too many (more than 5000)
            return;
        }
        
        //allow deletion of 2x the insert count (never exceeds 400)
        List<Message__c> insertableMessages = this.getSObjects();
        Integer numberToDelete = insertableMessages.size() * 2;
        
        //prepare earliest messages for deletion
        List<Id> idsToDelete = new List<Id>();
        for (Integer i = 0; i < numberToDelete; i++) idsToDelete.add(persistedMessages[i].Id);
        
        Database.delete(idsToDelete);
    }
    
    

}