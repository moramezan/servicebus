@IsTest public class VerticalBrokerImplementationTest {

    static testmethod void testMarkAndExecuteAndDoneConditions() {
        //arrange specific broker implementation
        insert new BrokerSettings__c(BrokerClassName__c = VerticalBrokerImplementation.class.getName());
        
        //arrange processes
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange steps
        Step__c step = StepObject.generateOne(sequence.Id, terminateProcess.Id);
        
        //arrange message
        Message__c message = new Message__c(
            Status__c = 'Buffered',
            Parameters__c = Json.serialize(new Map<String,Object> {
                'eda_SequenceName' => 'TestSequence',
                'eda_Position' => 0
            })
        );
        insert message;
        
        //act (enqueue)
        VerticalBrokerImplementation impl = (VerticalBrokerImplementation)Broker.impl();
        impl.resolve(new List<Message__c>{message});
        update message;
        
        //assert
        Integer expectedCount = 1;
        Integer actualCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Buffered'];
        System.assertEquals(expectedCount, actualCount, 'Message should be buffered.');
        
        //act (mark)
        List<SObject> scopes = new List<SObject>();
        impl.execute(null, scopes);
        
        //assert
        expectedCount = 1;
        actualCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Started'];
        System.assertEquals(expectedCount, actualCount, 'Message should be started.');
        System.assert(!impl.abortJob, 'Job should not be aborted.');
        
        //act (execute)
        Id messageId = [SELECT Id FROM Message__c WHERE Status__c = 'Started'].Id;
        System.debug(SalesforceObject.getById(step.Id));
        impl.execute(null, scopes);
        
        //assert
        expectedCount = 1;
        actualCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Completed'];
        System.assertEquals(expectedCount, actualCount, 'Message should be completed.');
        System.assert(!impl.abortJob, 'Job should not be aborted.');
        
        //act (done)
        impl.execute(null, scopes);
        System.assert(impl.abortJob, 'Job should be aborted.');
    }

    static testmethod void testMarkLimitedToTotalPotentialMarksWhenBufferedMessagesGtTotalPotentialMarks() {
        //arrange specific broker implementation
        insert new BrokerSettings__c(BrokerClassName__c = VerticalBrokerImplementation.class.getName());
        
        //arrange processes
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange steps
        Step__c step = StepObject.generateOne(sequence.Id, terminateProcess.Id);
        
        //arrange messages
        Message__c message01 = new Message__c(
            Status__c = 'Buffered',
            Parameters__c = Json.serialize(new Map<String,Object> {
                'eda_SequenceName' => 'TestSequence',
                'eda_Position' => 0
            })
        );
        insert message01;
            
        Message__c message02 = new Message__c(
            Status__c = 'Buffered',
            Parameters__c = Json.serialize(new Map<String,Object> {
                'eda_SequenceName' => 'TestSequence',
                'eda_Position' => 0
            })
        );
        insert message02;
        
        Message__c message03 = new Message__c(
            Status__c = 'Buffered',
            Parameters__c = Json.serialize(new Map<String,Object> {
                'eda_SequenceName' => 'TestSequence',
                'eda_Position' => 0
            })
        );
        insert message03;
        
        Integer totalPotentialMarks = 2; // Less than Buffered Messages Count
        VerticalBrokerImplementation.TotalPotentialMarks = totalPotentialMarks;
        
        
        //arrange resolution
        VerticalBrokerImplementation impl = (VerticalBrokerImplementation)Broker.impl();
        impl.resolve(new List<Message__c>{message01});
        update message01;
        impl.resolve(new List<Message__c>{message02});
        update message02;
        impl.resolve(new List<Message__c>{message03});
        update message03;  
        Integer actualBufferedCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Buffered'];
        
        //act
        List<SObject> scopes = new List<SObject>();
        impl.execute(null, scopes);
        
        //assemble
        Integer actualCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Started'];
        
        //assert
        System.assert(actualBufferedCount > 0, 'Buffered Messages should be greater than zero');    
        Integer expectedCount = (totalPotentialMarks > actualBufferedCount) ? actualBufferedCount : totalPotentialMarks; 
        System.assertEquals(expectedCount, actualCount, 'Message should be started.');
        System.assert(!impl.abortJob, 'Job should not be aborted.');    
    }

    static testmethod void testMarkLimitedToTotalBufferedMessagesWhenTotalPotentialMarksGtTotaBufferedMessagesCount() {
        //arrange specific broker implementation
        insert new BrokerSettings__c(BrokerClassName__c = VerticalBrokerImplementation.class.getName());
        
        //arrange processes
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange steps
        Step__c step = StepObject.generateOne(sequence.Id, terminateProcess.Id);
        
        //arrange messages
        Message__c message01 = new Message__c(
            Status__c = 'Buffered',
            Parameters__c = Json.serialize(new Map<String,Object> {
                'eda_SequenceName' => 'TestSequence',
                'eda_Position' => 0
            })
        );
        insert message01;
            
        Message__c message02 = new Message__c(
            Status__c = 'Buffered',
            Parameters__c = Json.serialize(new Map<String,Object> {
                'eda_SequenceName' => 'TestSequence',
                'eda_Position' => 0
            })
        );
        insert message02;
        
        Message__c message03 = new Message__c(
            Status__c = 'Buffered',
            Parameters__c = Json.serialize(new Map<String,Object> {
                'eda_SequenceName' => 'TestSequence',
                'eda_Position' => 0
            })
        );
        insert message03;
        
        Integer totalPotentialMarks = 4;  // Greater than Buffered Messages Count
        VerticalBrokerImplementation.TotalPotentialMarks = totalPotentialMarks;

        //arrange resolution
        VerticalBrokerImplementation impl = (VerticalBrokerImplementation)Broker.impl();
        impl.resolve(new List<Message__c>{message01});
        update message01;
        impl.resolve(new List<Message__c>{message02});
        update message02;
        impl.resolve(new List<Message__c>{message03});
        update message03;  
        Integer actualBufferedCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Buffered'];
        
        //act
        List<SObject> scopes = new List<SObject>();
        impl.execute(null, scopes);
        
        //assemble
        Integer actualCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Started'];
        
        //assert
        System.assert(actualBufferedCount > 0, 'Buffered Messages should be greater than zero');    
        Integer expectedCount = (totalPotentialMarks > actualBufferedCount) ? actualBufferedCount : totalPotentialMarks; 
        System.assertEquals(expectedCount, actualCount, 'Message should be started.');
        System.assert(!impl.abortJob, 'Job should not be aborted.');    
    }



    private class IdUtility {    
        private Integer Sequence = 0;
        private String  Prefix;
        
        @testVisible
        public IdUtility(SObjectType sot) {  
            this.Prefix = sot.getDescribe().getKeyPrefix();
        }
        
        @testVisible
        private Id getNext() { 
            this.Sequence++;
            string sequenceString = string.ValueOf(this.Sequence);
            
            String id = this.Prefix + '0000A0000000' ;
            id = id.left(id.length() - sequenceString.length() );
            id = id + sequenceString ;

            string suffix = '';
            integer flags;
            for (integer i = 0; i < 3; i++) {            
                flags = 0;
                for (integer j = 0; j < 5; j++)  { 
                    string c = id.substring(i * 5 + j,i * 5 + j + 1);
                    if (c.toUpperCase().equals(c) && c >= 'A' && c <= 'Z') { 
                        flags = flags + (1 << j);
                    }
                }
                
                suffix = (flags <= 25)  ? 
                    suffix + 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.substring(flags,flags+1) :
                    suffix + '012345'.substring(flags-25,flags-24);
            }
            
            return (Id) (id + suffix);
        }
    }

    static testmethod void callingGetChunkedAndMarkedMessagesReturnExpectedCollection() {
        //arrange
        IdUtility messageIdUtility = new IdUtility(Message__c.getSObjectType());
        Id messageAId = messageIdUtility.getNext();
        Id messageBId = messageIdUtility.getNext();
        Id messageCId = messageIdUtility.getNext();

        Map<Id,Message__c> markedMessages = new Map<Id,Message__c>{
            messageAId => new Message__c(Id = messageAId),
            messageBId => new Message__c(Id = messageBId),
            messageCId => new Message__c(Id = messageCId)
        };

        //act
        Map<Id,Message__c> actualChunkedAndMarkedMessages =  VerticalBrokerImplementation.getChunkedAndMarkedMessages(
             markedMessages
        );

        //assert
        System.assertEquals(true, actualChunkedAndMarkedMessages.size() == 1);
        Id actualChunkedAndMarkedMessageId  = new List<Id>(actualChunkedAndMarkedMessages.keySet())[0];
        System.assertEquals(true, markedMessages.keyset().contains(actualChunkedAndMarkedMessageId));
    }   
    
    static testmethod void callingGetRemainingMarkedMessagesReturnsExpectedCollection() {
        //arrange
        IdUtility messageIdUtility = new IdUtility(Message__c.getSObjectType());
        Id messageAId = messageIdUtility.getNext();
        Id messageBId = messageIdUtility.getNext();
        Id messageCId = messageIdUtility.getNext();
        Id messageDId = messageIdUtility.getNext();
        Id messageEId = messageIdUtility.getNext();
        
        Message__c messageAMarked = new Message__c(Id = messageAId);
        Message__c messageBMarked = new Message__c(Id = messageBId);
        Message__c messageCMarked = new Message__c(Id = messageCId);
        Message__c messageDMarked = new Message__c(Id = messageDId);
        Message__c messageEMarked = new Message__c(Id = messageEId); 
        Message__c messageBChunked = new Message__c(Id = messageBId);
        Message__c messageCChunked = new Message__c(Id = messageCId);
        
        Map<Id,Message__c> markedMessages  = new Map<Id,Message__c>{
            messageAId => messageAMarked,
            messageBId => messageBMarked,
            messageCId => messageCMarked,
            messageDId => messageDMarked,
            messageEId => messageEMarked   
        };
        
        Map<Id,Message__c> chunkedAndMarkedMessages = new Map<Id,Message__c>{
            messageBId => messageBChunked,
            messageCId => messageCChunked
        };
        
        //act
        Map<Id,Message__c> actualRemainingMarkedMessages = VerticalBrokerImplementation.getRemainingMarkedMessages(
            markedMessages,
            chunkedAndMarkedMessages
        );
        
        //assemble
        Set<Id> expectedIds = new Set<Id>{messageAId, messageDId, messageEId};
        Boolean actualFlag =  actualRemainingMarkedMessages.keySet().containsAll(expectedIds);        
        
        //assert
        Integer expectedCount = markedMessages.keySet().size() - chunkedAndMarkedMessages.keySet().size();
        System.assertEquals(expectedCount, actualRemainingMarkedMessages.keySet().size());
        System.assertEquals(true, actualFlag);
    } 
}