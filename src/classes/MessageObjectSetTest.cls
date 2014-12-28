@IsTest public class MessageObjectSetTest {
    
    static testmethod void testUnpopulatedRouteKey() {
        //arrange message
        Message__c message = new Message__c(
            Parameters__c = '{"esb_IsHeartbeatProcess":true}'
        );
        
        //act
        new MessageObjectSet(new List<Message__c>{message}).populateRouteKey();
        
        //assert
        String expectedRoute = null;
        String actualRoute = message.Route__c;
        System.assertEquals(expectedRoute, actualRoute, 'Route should be null for heartbeats.');
    }
    
    static testmethod void testPopulateRouteKey() {
        //arrange message
        Message__c message = new Message__c(
            Parameters__c = '{"esb_SequenceName":"test","esb_Position":1}'
        );
        
        //act
        new MessageObjectSet(new List<Message__c>{message}).populateRouteKey();
        
        //assert
        String expectedRoute = 'test#1';
        String actualRoute = message.Route__c;
        System.assertEquals(expectedRoute, actualRoute, 'Route incorrectly populated.');
    }
    
    static testmethod void testValidMessageParameters() {
        //arrange message
        Message__c validMessage = new Message__c(
            Parameters__c = '{"esb_SequenceName":"test","esb_Position":1}'
        );
        
        //assert
        System.assert(!ApexPages.hasMessages(), 'Should not have errors before.');
        
        //act
        new MessageObjectSet(new List<Message__c>{validMessage}).validateJsonParameters();
        
        //assert
        System.assert(!ApexPages.hasMessages(), 'Should not have errors after.');
    }
    
    static testmethod void testInvalidMessageParameters() {
        //arrange message
        Message__c validMessage = new Message__c(
            Parameters__c = '{...}'
        );
        
        //assert
        System.assert(!ApexPages.hasMessages(), 'Should not have errors before.');
        
        //act
        new MessageObjectSet(new List<Message__c>{validMessage}).validateJsonParameters();
        
        //assert
        System.assert(ApexPages.hasMessages(), 'Should have errors after.');
    }
    
    static testmethod void correctlyDeletesExpiredCompletedMessages() {
        // arrange
        MessageObjectSet.triggerEnabled = false;
        MessageObjectSet.MaxTimeToLiveInDays  = 20;
        MessageObjectSet.MaxCompletedMessages = 5000;
        MessageObjectSet.MaxTotalMessages     = 5000; 
        MessageObjectSet.MaxDML               = 5000;
        
        DateTime currentStamp =  System.now();
        DateTime thresholdStamp =  currentStamp.addDays(MessageObjectSet.MaxTimeToLiveInDays  * -1);

        List<String> expectedMissingTags = new List<String>{'0','1','2','3'};
        List<String> expectedExistingTags = new List<String>{'4','5','6'};

        List<Message__c> messagesA = new List<Message__c>();

        //
        // -- ( very long ago )
        // -- expect to be deleted : end
        messagesA.add(new Message__c(Exception__c = expectedMissingTags[0], Status__c = 'Completed', CreatedDate__c = thresholdStamp.addDays(4 * -1)));
        messagesA.add(new Message__c(Exception__c = expectedMissingTags[1], Status__c = 'Completed', CreatedDate__c = thresholdStamp.addDays(3 * -1)));
        messagesA.add(new Message__c(Exception__c = expectedMissingTags[2], Status__c = 'Completed', CreatedDate__c = thresholdStamp.addDays(2 * -1)));
        messagesA.add(new Message__c(Exception__c = expectedMissingTags[3], Status__c = 'Completed', CreatedDate__c = thresholdStamp.addDays(1 * -1)));
        // -- expect to be deleted : beg
        // -- theshold stamp  ( a few days ago )
        messagesA.add(new Message__c(Exception__c = expectedExistingTags[0], Status__c = 'Completed', CreatedDate__c = thresholdStamp.addDays(1)));
        messagesA.add(new Message__c(Exception__c = expectedExistingTags[1], Status__c = 'Completed', CreatedDate__c = thresholdStamp.addDays(2)));
        messagesA.add(new Message__c(Exception__c = expectedExistingTags[2], Status__c = 'Completed', CreatedDate__c = thresholdStamp.addDays(3)));
        // -- ( very recent past ) 
        // -- current stamp 
        //   

        insert messagesA; 

        // act
        MessageObjectSet messageObjectSetInstance = new MessageObjectSet(new List<Message__c>{new Message__c(Status__c = 'Buffered')});
        messageObjectSetInstance.deleteExpiredAndCompleted(currentStamp); 

        // assemble
        List<Message__c> actualPersistedCompleted  =  [SELECT Id, Exception__c  FROM Message__c ];
        Integer actualPersistedCompletedCount  = actualPersistedCompleted.size(); 
        Set<String> actualTags = new Set<String>();   
        for (Message__c message : actualPersistedCompleted ) {
            actualTags.add(message.Exception__c);
        }
        Boolean actualExistingFlag = actualTags.containsAll(expectedExistingTags);
        Boolean actualMissingFlag = 
            actualTags.contains(expectedMissingTags[0]) || actualTags.contains(expectedMissingTags[1]) ||
            actualTags.contains(expectedMissingTags[2]) || actualTags.contains(expectedMissingTags[3]) ;

        // assert
        Integer expectedPersistedCompletedCount  = expectedExistingTags.size();   
        Boolean expectedExistingFlag = true;
        Boolean expectedMissingFlag = false;  
        System.assertEquals(expectedPersistedCompletedCount, actualPersistedCompletedCount);
        System.assertEquals(expectedExistingFlag, actualExistingFlag);
        System.assertEquals(expectedMissingFlag, actualMissingFlag);
    }
    
    static testmethod void correctlyDeletesExcessiveMessages() {

        // arrange
        MessageObjectSet.triggerEnabled = false;
        MessageObjectSet.MaxTimeToLiveInDays  = 20;
        MessageObjectSet.MaxCompletedMessages = 5000;
        MessageObjectSet.MaxTotalMessages     = 4; 
        MessageObjectSet.MaxDML               = 5000;

        // scenario:
        //  IC  = insertable count
        //  PC  = persisted count
        //  TC  = total count = PC + IC = 4 + 2 = 6
        //  EC  = excess count = TC - MaxTotalMessages = 6 - 4 = 2
        //  expectedMissingTags {'0','1'} are the [2] oldest with Completed status and should therefore be deleted

        DateTime currentStamp =  System.now();

        List<String> expectedMissingTags = new List<String>{'0','1'};
        List<String> expectedExistingTags = new List<String>{'2','3'};
        List<String> beforeTags = new List<String>{'4','5'};
        
        List<Message__c> messagesA = new List<Message__c>();
        messagesA.add(new Message__c(Exception__c = expectedMissingTags[0], Status__c = 'Completed', CreatedDate__c = currentStamp.addDays(4 * -1)));
        messagesA.add(new Message__c(Exception__c = expectedMissingTags[1], Status__c = 'Completed', CreatedDate__c = currentStamp.addDays(3 * -1)));
        messagesA.add(new Message__c(Exception__c = expectedExistingTags[0], Status__c = 'Completed', CreatedDate__c = currentStamp.addDays(2 * -1)));
        messagesA.add(new Message__c(Exception__c = expectedExistingTags[1], Status__c = 'Started', CreatedDate__c = currentStamp.addDays(1 * -1)));
        // -- ( very recent past ) 
        // -- current stamp 
        // 

        insert messagesA; 

        List<Message__c> messagesB = new List<Message__c>();
        messagesB.add(new Message__c(Exception__c = beforeTags[0],  Status__c = 'Buffered'));
        messagesB.add(new Message__c(Exception__c = beforeTags[1],  Status__c = 'Buffered'));

        // act
        MessageObjectSet messageObjectSetInstance = new MessageObjectSet(messagesB);
        messageObjectSetInstance.deleteExcessiveAll();

        // assemble
        List<Message__c> actualPersisted  =  [SELECT Id, Exception__c  FROM Message__c ];
        Integer actualPersistedCount  = actualPersisted.size(); 
        Set<String> actualTags = new Set<String>();   
        for (Message__c message : actualPersisted ) {
            actualTags.add(message.Exception__c);
        }
        Boolean actualExistingFlag = actualTags.containsAll(expectedExistingTags);
        Boolean actualMissingFlag = 
            actualTags.contains(expectedMissingTags[0]) || actualTags.contains(expectedMissingTags[1])   ;

        // assert
        Integer expectedPersistedCount = expectedExistingTags.size();  
        Boolean expectedExistingFlag = true;
        Boolean expectedMissingFlag = false;  
        System.assertEquals(expectedPersistedCount, actualPersistedCount);
        System.assertEquals(expectedExistingFlag, actualExistingFlag);
        System.assertEquals(expectedMissingFlag, actualMissingFlag);
    }


    static testmethod void correctlyDeletesExcessiveCompletedeMessages() {

        // arrange
        MessageObjectSet.triggerEnabled = false;
        MessageObjectSet.MaxTimeToLiveInDays  = 20;
        MessageObjectSet.MaxCompletedMessages = 2;
        MessageObjectSet.MaxTotalMessages     = 5000; 
        MessageObjectSet.MaxDML               = 5000;

        // scenario:
        //  PCC  = persisted COMPLETED count
        //  EC  = excess count = PCC - MaxCompletedMessages = 3 - 2 = 1
        //  expectedMissingTags {'0'} is the oldest  with Completed status and should therefore be deleted

        DateTime currentStamp =  System.now();
        List<Message__c> messagesA = new List<Message__c>();

        List<String> expectedMissingTags = new List<String>{'0'};
        List<String> expectedExistingTags = new List<String>{'1','2','3'};
        List<String> beforeTags = new List<String>{'4','5'};

        messagesA.add(new Message__c(Exception__c = expectedMissingTags[0], Status__c = 'Completed', CreatedDate__c = currentStamp.addDays(4 * -1)));
        messagesA.add(new Message__c(Exception__c = expectedExistingTags[0], Status__c = 'Completed', CreatedDate__c = currentStamp.addDays(3 * -1)));
        messagesA.add(new Message__c(Exception__c = expectedExistingTags[1], Status__c = 'Completed', CreatedDate__c = currentStamp.addDays(2 * -1)));
        messagesA.add(new Message__c(Exception__c = expectedExistingTags[2], Status__c = 'Started', CreatedDate__c = currentStamp.addDays(1 * -1)));
        // -- ( very recent past ) 
        // -- current stamp 
        // 

        insert messagesA; 

        List<Message__c> messagesB = new List<Message__c>();
        messagesB.add(new Message__c(Exception__c = beforeTags[0],  Status__c = 'Buffered'));
        messagesB.add(new Message__c(Exception__c = beforeTags[1],  Status__c = 'Buffered'));

        // act
        MessageObjectSet messageObjectSetInstance = new MessageObjectSet(messagesB);
        messageObjectSetInstance.deleteExcessiveCompleted();

        // assemble
        List<Message__c> actualPersisted  =  [SELECT Id, Exception__c  FROM Message__c ];
        Integer actualPersistedCount  = actualPersisted.size(); 
        Set<String> actualTags = new Set<String>();   
        for (Message__c message : actualPersisted ) {
            actualTags.add(message.Exception__c);
        }
        Boolean actualExistingFlag = actualTags.containsAll(expectedExistingTags);
        Boolean actualMissingFlag =  actualTags.contains(expectedMissingTags[0]) ;

        // assert
        Integer expectedPersistedCount = expectedExistingTags.size();   
        Boolean expectedExistingFlag = true;
        Boolean expectedMissingFlag = false;  
        System.assertEquals(expectedPersistedCount, actualPersistedCount);
        System.assertEquals(expectedExistingFlag, actualExistingFlag);
        System.assertEquals(expectedMissingFlag, actualMissingFlag);
    }
    
    static testmethod void correctlyDeletesExcessiveMessagesUpToDmlConstraint() {

        // arrange
        MessageObjectSet.triggerEnabled = false;
        MessageObjectSet.MaxTimeToLiveInDays  = 20;
        MessageObjectSet.MaxCompletedMessages = 5000;
        MessageObjectSet.MaxTotalMessages     = 4; 
        MessageObjectSet.MaxDML               = 1;

        // scenario - edge case :
        //  IC  = insertable count
        //  PC  = persisted count
        //  TC  = total count = PC + IC = 4 + 2 = 6
        //  EC  = excess count = TC - MaxTotalMessages = 6 - 4 = 2
        //  expectedMissingTags {'0'} and expectedExistingTags {'1'} are the [2] oldest with Completed status and 
        //                  should therefore be deleted
        //  only expectedMissingTags {'0'} will be deleted because MaxDML  limits  deletion to 1 record only

        DateTime currentStamp =  System.now();
        List<Message__c> messagesA = new List<Message__c>();
 
        List<String> expectedMissingTags = new List<String>{'0'};
        List<String> expectedExistingTags = new List<String>{'1','2','3'};
        List<String> beforeTags = new List<String>{'4','5'};

        messagesA.add(new Message__c(Exception__c = expectedMissingTags[0], Status__c = 'Completed', CreatedDate__c = currentStamp.addDays(4 * -1)));
        messagesA.add(new Message__c(Exception__c = expectedExistingTags[0], Status__c = 'Completed', CreatedDate__c = currentStamp.addDays(3 * -1)));
        messagesA.add(new Message__c(Exception__c = expectedExistingTags[1], Status__c = 'Completed', CreatedDate__c = currentStamp.addDays(2 * -1)));
        messagesA.add(new Message__c(Exception__c = expectedExistingTags[2], Status__c = 'Started', CreatedDate__c = currentStamp.addDays(1 * -1)));
        // -- ( very recent past ) 
        // -- current stamp 
        // 

        insert messagesA; 

        List<Message__c> messagesB = new List<Message__c>();
        messagesB.add(new Message__c(Exception__c = beforeTags[0],  Status__c = 'Buffered'));
        messagesB.add(new Message__c(Exception__c = beforeTags[1],  Status__c = 'Buffered'));

        // act
        MessageObjectSet messageObjectSetInstance = new MessageObjectSet(messagesB);
        messageObjectSetInstance.deleteExcessiveAll();

        // assemble
        List<Message__c> actualPersisted  =  [SELECT Id, Exception__c  FROM Message__c ];
        Integer actualPersistedCount  = actualPersisted.size(); 
        Set<String> actualTags = new Set<String>();   
        for (Message__c message : actualPersisted ) {
            actualTags.add(message.Exception__c);
        }
        Boolean actualExistingFlag = actualTags.containsAll(expectedExistingTags);
        Boolean actualMissingFlag =   actualTags.contains(expectedMissingTags[0])   ;

        // assert
        Integer expectedPersistedCount = expectedExistingTags.size();   
        Boolean expectedExistingFlag = true;
        Boolean expectedMissingFlag = false;  
        System.assertEquals(expectedPersistedCount, actualPersistedCount);
        System.assertEquals(expectedExistingFlag, actualExistingFlag);
        System.assertEquals(expectedMissingFlag, actualMissingFlag);
    }
    
    
    
    static testmethod void triggerCorrectlyDeletesCompletedMessages() {

        // arrange
        MessageObjectSet.triggerEnabled = false;
        MessageObjectSet.MaxTimeToLiveInDays  = 20;
        MessageObjectSet.MaxCompletedMessages = 1;
        MessageObjectSet.MaxTotalMessages     = 4; 
        MessageObjectSet.MaxDML               = 2;

        // expected scenario   :
        // - deleteExpiredAndCompleted()executes:
        //      {0,1,2,3} are past stamp threshold and should be deleted , but MaxDML limit of 2
        //      results in just {0,1} being deleted 
        // - deleteExcessiveAll() executes:
        //      count[ {2,3,4,5,6}, {7,8,9,10} ] == 9 versus MaxTotalMessages == 4 
        //      suggests deleting 9 - 4 = 5 provided the status is COMPLETED
        //      resulting in {2,3,4,5} because {6} is STARTED
        //      only {2,3} are deleted because  MaxDML limit == 2
        // - deleteExcessiveCompleted() executes:
        //    MaxCompletedMessages == 1 resulting in {4} of candidates {4,5} being deleted
        //    the maxDml constraint == 2  is not exceeded  
        //
        //  after the trigger fires we therefore expect {5,6,7,8,9,10} to be persisted

        DateTime currentStamp =  System.now();
        DateTime thresholdStamp =  currentStamp.addDays(MessageObjectSet.MaxTimeToLiveInDays  * -1);
        List<Message__c> messagesA = new List<Message__c>();

        List<String> expectedMissingTags = new List<String>{'0','1','2','3','4'};
        List<String> expectedExistingTags = new List<String>{'5','6','7','8','9','10'};

        //
        // -- ( very long ago )
        messagesA.add(new Message__c(Exception__c = expectedMissingTags[0], Status__c = 'Completed', CreatedDate__c = thresholdStamp.addDays(4 * -1)));
        messagesA.add(new Message__c(Exception__c = expectedMissingTags[1], Status__c = 'Completed', CreatedDate__c = thresholdStamp.addDays(3 * -1)));
        messagesA.add(new Message__c(Exception__c = expectedMissingTags[2], Status__c = 'Completed', CreatedDate__c = thresholdStamp.addDays(2 * -1)));
        messagesA.add(new Message__c(Exception__c = expectedMissingTags[3], Status__c = 'Completed', CreatedDate__c = thresholdStamp.addDays(1 * -1)));
        // -- theshold stamp  ( a few days ago )
        messagesA.add(new Message__c(Exception__c = expectedMissingTags[4], Status__c = 'Completed', CreatedDate__c = thresholdStamp.addDays(1)));
        messagesA.add(new Message__c(Exception__c = expectedExistingTags[0], Status__c = 'Completed', CreatedDate__c = thresholdStamp.addDays(2)));
        messagesA.add(new Message__c(Exception__c = expectedExistingTags[1], Status__c = 'Started', CreatedDate__c = thresholdStamp.addDays(3)));

        // -- ( very recent past ) 
        // -- current stamp 
        //   
        
        insert messagesA; 

        List<Message__c> messagesB = new List<Message__c>();
        messagesB.add(new Message__c(Exception__c = expectedExistingTags[2],  Status__c = 'Buffered'));
        messagesB.add(new Message__c(Exception__c = expectedExistingTags[3],  Status__c = 'Buffered'));
        messagesB.add(new Message__c(Exception__c = expectedExistingTags[4],  Status__c = 'Buffered'));
        messagesB.add(new Message__c(Exception__c = expectedExistingTags[5],  Status__c = 'Buffered')); 

        // act
        MessageObjectSet.triggerEnabled = true;
        insert messagesB; 

        // assemble
        List<Message__c> actualPersisted  =  [SELECT Id, Exception__c  FROM Message__c ];
        Integer actualPersistedCount  = actualPersisted.size(); 
        Set<String> actualTags = new Set<String>();   
        for (Message__c message : actualPersisted ) {
            actualTags.add(message.Exception__c);
        }
        Boolean actualExistingFlag = actualTags.containsAll(expectedExistingTags);
        Boolean actualMissingFlag =   
            actualTags.contains(expectedMissingTags[0]) || actualTags.contains(expectedMissingTags[1]) ||
            actualTags.contains(expectedMissingTags[2]) || actualTags.contains(expectedMissingTags[3]) ||
            actualTags.contains(expectedMissingTags[4]);

        // assert
        Integer expectedPersistedCount = expectedExistingTags.size(); 
        Boolean expectedExistingFlag = true;
        Boolean expectedMissingFlag = false;  
        System.assertEquals(expectedPersistedCount, actualPersistedCount);
        System.assertEquals(expectedExistingFlag, actualExistingFlag);
        System.assertEquals(expectedMissingFlag, actualMissingFlag);
    }


    static testmethod void canDisableTrigger() {
        // arrange
        MessageObjectSet.MaxTimeToLiveInDays  = 3;
        MessageObjectSet.MaxCompletedMessages = 2;
        MessageObjectSet.MaxTotalMessages     = 2; 
        MessageObjectSet.MaxDML               = 5000;
 
        Integer arbitaryExcessMessageCount = 5;
        List<Message__c> messagesA = new List<Message__c>();
        List<Message__c> messagesB = new List<Message__c>();
        Integer total = MessageObjectSet.MaxTotalMessages  + arbitaryExcessMessageCount;
        Integer i = 1;
        while (i <= total) {
            messagesA.add(new Message__c(Status__c = 'Completed'));
            messagesB.add(new Message__c(Status__c = 'Completed'));
            i++;   
        }

        // act
        MessageObjectSet.triggerEnabled = false;
        insert messagesA;     
        insert messagesB;

        // assemble
        Integer actualPersistedCompletedCount =  [SELECT COUNT() FROM Message__c WHERE Status__c = 'Completed'];

        // assert
        Integer expectedPersistedCompletedCount = total * 2; // A + B
        System.assertEquals(expectedPersistedCompletedCount, actualPersistedCompletedCount);
    }
}