public with sharing class MessageObjectSet extends SalesforceObjectSet {
    
    /**
     * Prevent message inserts per #677
     * (Change this flag sparingly only)
     */
    static public Boolean Inhibit = true;
    
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
    
    /**
     * Fields can only be changed if Apex is
     * used to unset the Inhibit static.
     */
    @TestVisible private void inhibitCreationFromGui() {
        List<Message__c> messages = this.getSObjects();
        
        for (Integer i = 0; i < messages.size(); i++) {
            if (Inhibit) messages[i].addError('Messages cannot be created from the GUI.');
        }
    }
    
    override public void onBeforeInsert() {
        this.inhibitCreationFromGui();
        deleteCompletedMessages(System.now());   
        this.validateJsonParameters();
        this.interpretEsbSequenceName();
        this.populateRouteKey();
    }
    
    override public void onBeforeUpdate(List<SObject> oldObjects) {
        this.validateJsonParameters();
        this.interpretEsbSequenceName();
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
     * In #658 we hoped to expose esb__SequenceName API in Broker.persist() but
     * it meant we can't insert messages then just 'run' broker over them. Further
     * issue #677 feels like we probably shouldn't be inserting messages at all.
     * 
     * We want to interpret esb__SequenceName into __SequenceName and __Position
     * as late and as simply as possible. Doing it here in the trigger works OK.
     */
    public void interpretEsbSequenceName() {
        List<Message__c> messages = this.getSObjects();
        for (Message__c message : messages) {
            //user nominated Sequence (no esb prefix)
            Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(message.Parameters__c);
            if (parameters.get('esb__SequenceName') == null) continue; //nothing to do
            
            parameters.put('__SequenceName', parameters.get('esb__SequenceName'));
            parameters.put('__Position', 1);
            parameters.put('esb__SequenceName', null);
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