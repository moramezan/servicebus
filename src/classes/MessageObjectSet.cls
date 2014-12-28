public with sharing class MessageObjectSet extends SalesforceObjectSet {
    
    /*
     * Note : this flag is purely for TDD purposes 
     */
    @TestVisible private static Boolean triggerEnabled = true;
    
    @TestVisible static private Integer MaxTimeToLiveInDays  = 30;
    @TestVisible static private Integer MaxCompletedMessages = 4000;
    @TestVisible static private Integer MaxTotalMessages     = 5000; 
    @TestVisible static private Integer MaxDML               = 5000;
    
    public MessageObjectSet(List<Message__c> messages) {
        super(messages);
    }
    
    override public void onBeforeInsert() {
        deleteCompletedMessages(System.now());   
        this.validateJsonParameters();
        this.populateRouteKey();
    }
    
    override public void onBeforeUpdate(List<SObject> oldObjects) {
        this.validateJsonParameters();
        this.populateRouteKey();
    }
    
    /**
     * Unrelated to former term "resolve" (which now refers to PROCESS location)
     * this is just a convenience to increment the position of a bunch of messages.
     */
    public void incrementPositions() {
        List<Message__c> messages = this.getSObjects();
        for (Message__c message : messages) {
            Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(message.Parameters__c);
            Integer position = (Integer)parameters.get('__Position');
            parameters.put('__Position', ++position);
            message.Parameters__c = Json.serializePretty(parameters);
        }
    }
    
    /**
     * It's not sensible to query on the JSON formatted SequenceName and Position
     * but what we can do is make sure those guys are always concatenated into a key.
     */
    @TestVisible private void populateRouteKey() {
        List<Message__c> messages = this.getSObjects();
        
        for (Message__c message : messages) {
            Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(message.Parameters__c);
            Boolean isHeartbeatProcess = (Boolean)parameters.get('__IsHeartbeatProcess');
            if (isHeartbeatProcess == true) continue; //#575 crow look, don't try to route
            
            String sequence = (String)parameters.get('__SequenceName');
            Integer position = (Integer)parameters.get('__Position');
            message.Route__c = sequence + '#' + position;
        }
    }
    
    /**
     * Ensure that Message Parameters are always valid JSON #660
     * So that we can trust them in the Broker and keep code simple.
     */
    @TestVisible private void validateJsonParameters() {
        List<Message__c> messages = this.getSObjects();
        
        for (Message__c message : messages) {
            try {
                Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(message.Parameters__c);
            } catch (JsonException e) {
                message.Parameters__c.addError(e);
            }
        }
    }

     /*
      *  Users may wish to view completed messages. The question then arises,
      *  how many and how long should these completed messages persist for?
      *  - On the time to live (TTL) question:
      *    Any completed message older then the TTL should be deleted
      *  - On the how many question:
      *    Delete completed messages that cause the count of all messages to exceed a 
      *      specified "all-messages threshold"
      *    Delete completed messages that cause the count of all completed messages
      *      to exceed a specified "completed messages threshold" 
      *
      *  The following algorithm specifies the above intent
      *     1. Delete Completed messages that have passed their time to live (TTL)  
      *     2. Delete Completed messages (oldest first) so that 
      *        (COUNT[current persisted messages] + COUNT[insertable messages]) <= MaxTotalMessages
      *     3. Delete Completed messages (oldest first) so that 
      *        COUNT[Completed persisted messages] <= MaxCompletedMessages
      *   For steps 1,2 and 3, limit all DML to MaxDML
      */
    @testVisible private  void deleteCompletedMessages(DateTime now) {
        if (triggerEnabled) {
            deleteExpiredAndCompleted(now);
            deleteExcessiveAll();
            deleteExcessiveCompleted();   
        }
    }


    @testVisible private  void deleteExpiredAndCompleted(DateTime now) {
        DateTime threshold = now.addDays(MaxTimeToLiveInDays * -1);
        
        List<Message__c> expiredAndCompletedMessages = [
            SELECT Id
            FROM Message__c
            WHERE Status__c = 'Completed'
            AND CreatedDate__c < :threshold
            LIMIT :MaxDML
        ];
        
        delete expiredAndCompletedMessages;
    } 


    @testVisible private  void deleteExcessiveAll() {
        // excessiveMessagesCount
        Integer insertableMessagesCount = this.getSObjects().size();
        Integer persistedMessagesCount =  [SELECT COUNT() FROM Message__c WHERE IsDeleted = false];
        Integer excessiveMessagesCount =  (insertableMessagesCount + persistedMessagesCount) - MaxTotalMessages;
        
        // limit clause
        excessiveMessagesCount = excessiveMessagesCount < 0 ? 0 : excessiveMessagesCount;
        excessiveMessagesCount = excessiveMessagesCount > MaxDML ? MaxDML : excessiveMessagesCount;

        List<Message__c> excessiveMessages = [
            SELECT Id
            FROM Message__c
            WHERE Status__c = 'Completed'
            ORDER BY CreatedDate ASC
            LIMIT :excessiveMessagesCount
        ];
        
        delete excessiveMessages;    
    } 


    @testVisible private  void deleteExcessiveCompleted() {
        // excessiveCompletedCount
        Integer persistedCompletedCount =  [SELECT COUNT() FROM Message__c WHERE Status__c = 'Completed'];
        Integer excessiveCompletedCount =  persistedCompletedCount - MaxCompletedMessages;
        
        // limit clause
        excessiveCompletedCount = excessiveCompletedCount < 0 ? 0 : excessiveCompletedCount;
        excessiveCompletedCount = excessiveCompletedCount > MaxDML ? MaxDML : excessiveCompletedCount;

        List<Message__c> excessiveMessages = [
            SELECT Id
            FROM Message__c
            WHERE Status__c = 'Completed'
            ORDER BY CreatedDate ASC
            LIMIT :excessiveCompletedCount
        ];

        delete excessiveMessages;  
    } 
}