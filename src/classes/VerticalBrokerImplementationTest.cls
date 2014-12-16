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
                'esb_SequenceName' => 'TestSequence',
                'esb_Position' => 0
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
                'esb_SequenceName' => 'TestSequence',
                'esb_Position' => 0
            })
        );
        insert message01;
            
        Message__c message02 = new Message__c(
            Status__c = 'Buffered',
            Parameters__c = Json.serialize(new Map<String,Object> {
                'esb_SequenceName' => 'TestSequence',
                'esb_Position' => 0
            })
        );
        insert message02;
        
        Message__c message03 = new Message__c(
            Status__c = 'Buffered',
            Parameters__c = Json.serialize(new Map<String,Object> {
                'esb_SequenceName' => 'TestSequence',
                'esb_Position' => 0
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
                'esb_SequenceName' => 'TestSequence',
                'esb_Position' => 0
            })
        );
        insert message01;
            
        Message__c message02 = new Message__c(
            Status__c = 'Buffered',
            Parameters__c = Json.serialize(new Map<String,Object> {
                'esb_SequenceName' => 'TestSequence',
                'esb_Position' => 0
            })
        );
        insert message02;
        
        Message__c message03 = new Message__c(
            Status__c = 'Buffered',
            Parameters__c = Json.serialize(new Map<String,Object> {
                'esb_SequenceName' => 'TestSequence',
                'esb_Position' => 0
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

    static testmethod void callingGetAvailableContextsReturnsExpectedCount() {
        //arrange
        IdUtility messageIdUtility = new IdUtility(Message__c.getSObjectType());
        Id messageAId = messageIdUtility.getNext();
        Id messageBId = messageIdUtility.getNext();
        Id messageCId = messageIdUtility.getNext();
        Id messageDId = messageIdUtility.getNext();
        Id messageEId = messageIdUtility.getNext();

        List<Message__c> markableMessages = new List<Message__c>{
            new Message__c(Id = messageAId),
            new Message__c(Id = messageBId),
            new Message__c(Id = messageCId)
        };
        
        Map<Id,Message__c> markedMessages  = new Map<Id, Message__c>{
            messageDId => new Message__c(Id = messageDId),
            messageEId => new Message__c(Id = messageEId)
        };
          
        Integer remainingContexts = 7; 
          
        //act
        Integer actualAvailableContexts = VerticalBrokerImplementation.getAvailableContexts (
            remainingContexts, 
            markableMessages,
            markedMessages  
        );
    
        //assert
        Integer expectedAvailableContexts = 7 - 3 - 2 - 1;
        System.assertEquals( expectedAvailableContexts,actualAvailableContexts );
    }

    static testmethod void callingGetAdjustedMarkableMessagesReturnsExpectedCollection() {
        //arrange
        IdUtility messageIdUtility = new IdUtility(Message__c.getSObjectType());
        Id messageAId = messageIdUtility.getNext();
        Id messageBId = messageIdUtility.getNext();
        Id messageCId = messageIdUtility.getNext();

        List<Message__c> markableMessages = new List<Message__c>{
            new Message__c(Id = messageAId),
            new Message__c(Id = messageBId),
            new Message__c(Id = messageCId)
        };
 
        Integer availableContexts = 2;

        //act
        List<Message__c> actualAdjustedMarkableMessages = VerticalBrokerImplementation.getAdjustedMarkableMessages(
            markableMessages, 
            availableContexts
        );
 
        //assemble
        Integer actualCount = actualAdjustedMarkableMessages.Size();
        Set<Id> actualMessageIds  = (new Map<Id, Message__c>(actualAdjustedMarkableMessages)).keySet();
        Set<Id> expectedMessageIds  = (new Map<Id, Message__c>(markableMessages)).keySet();
        Boolean actualFlag = expectedMessageIds.containsAll(actualMessageIds);

        //assert
        Integer expectedCount = availableContexts;
        System.assertEquals( expectedCount, actualCount);
        System.assertEquals( true, actualFlag);
    }


    static testmethod void callingGetFullyQualifiedClassNameToLimitsReturnsExpectedCollection() {
        // arrange 
        Set<String> fullyQualifiedClassNames = new Set<String>{
            Terminate.class.getName(),   
            Gate.class.getName(),        
            Wiretap.class.getName()    
         };
        
        VerticalBrokerImplementation.IAttributeProvider attributeProvider = 
            new VerticalBrokerImplementation.AttributeProvider(fullyQualifiedClassNames);
        
        // act
        Map<String, Integer> getFullyQualifiedClassNameToLimits = 
            attributeProvider.getFullyQualifiedClassNameToLimits();
         
        // assemble  
        Integer actualTerminate = getFullyQualifiedClassNameToLimits.get(Terminate.class.getName());
        Integer actualGate = getFullyQualifiedClassNameToLimits.get(Gate.class.getName());
        Integer actualWiretap = getFullyQualifiedClassNameToLimits.get(Wiretap.class.getName());
        
          
        // assert
        Integer expectedTerminate = 90;
        system.assertEquals(expectedTerminate, actualTerminate);
        Integer expectedGate = 1;
        system.assertEquals(expectedGate, actualGate);
        Integer expectedWiretap = 1;
        system.assertEquals(expectedWiretap, actualWiretap);
    }
    
    static testmethod void callingGetFullyQualifiedClassNameToLimitsForMockReturnsExpectedCollection() {
        // arrange 
        Integer    mockedTerminateCount =  21;   
        Integer    mockedGateCount = 22;     
        Integer    mockedWiretapCount = 23;
            
        Map<String, Integer> mockedFullyQualifiedClassNameToLimits = new  Map<String, Integer>{
            Terminate.class.getName() => mockedTerminateCount,   
            Gate.class.getName() => mockedGateCount,        
            Wiretap.class.getName()  => mockedWiretapCount   
        };

       VerticalBrokerImplementation.IAttributeProvider attributeProvider = 
            new VerticalBrokerImplementation.MockAttributeProvider(mockedFullyQualifiedClassNameToLimits);
            
        // act
        Map<String, Integer> getFullyQualifiedClassNameToLimits = 
            attributeProvider.getFullyQualifiedClassNameToLimits();
         
        // assemble  
        Integer actualTerminate = getFullyQualifiedClassNameToLimits.get(Terminate.class.getName());
        Integer actualGate = getFullyQualifiedClassNameToLimits.get(Gate.class.getName());
        Integer actualWiretap = getFullyQualifiedClassNameToLimits.get(Wiretap.class.getName());
 
        // assert
        Integer expectedTerminate = mockedTerminateCount;
        system.assertEquals(expectedTerminate, actualTerminate);
        Integer expectedGate = mockedGateCount;
        system.assertEquals(expectedGate, actualGate);
        Integer expectedWiretap = mockedWiretapCount;
        system.assertEquals(expectedWiretap, actualWiretap);
    }  


    static testmethod void callingGetChunkedAndMarkedMessagesReturnsExpectedCollection01() {
        // Requirement : 
        //       Maximize the number of messages processed in a single context
        // Constraints / Rules
        //       - Messages must all be for the same process 
        //       - find highest number of messages for a single process limited by that 
        //         process's  maximum allowable invocations
        // Scenario  : 
        //       - Terminate has the highest allowable invocations 
        //       - Terminate has more than  enough messages to fill allowable invocations
        // Expect 
        //      - Return a collection of 2 Terminate messages
        Integer  mockedTerminateCount = 2;   
        Integer  mockedGateCount      = 1;     
        Integer  mockedWiretapCount   = 1;
        Integer totalTerminate =  3;
        Integer totalGate      =  2;
        Integer totalWiretap   =  2;

        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        Process__c gateProcess = ProcessObject.generateOne(Gate.class);
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);

        Map<String,Map<String,Object>> processNameToAttributes = new Map<String,Map<String,Object>>{
            terminateProcess.Name  =>  new Map<String,Object>{
                'Process' => terminateProcess,
                'Limits' => mockedTerminateCount,
                'TotalMessages' => totalTerminate       
            }, 
            gateProcess.Name  =>  new Map<String,Object>{
                'Process' => gateProcess,
                'Limits' => mockedGateCount,
                'TotalMessages' => totalGate      
            },
            wiretapProcess.Name  =>  new Map<String,Object>{
                'Process' => wiretapProcess,
                'Limits' => mockedWiretapCount,
                'TotalMessages' => totalWiretap       
            }     
        };

        // arrange - setup
        Map<String,Object> providerAndMessageIdToMessage = 
            setupProviderAndMessages(processNameToAttributes);
        VerticalBrokerImplementation.IAttributeProvider attributeProvider =   
            (VerticalBrokerImplementation.IAttributeProvider) providerAndMessageIdToMessage.get('Provider');
        Map<Id,Message__c> messageIdToMessage = 
            (Map<Id,Message__c>) providerAndMessageIdToMessage.get('MessageIdToMessage');
    
        //act
        Map<Id,Message__c> chunkedAndMarkedMessages =   VerticalBrokerImplementation.getChunkedAndMarkedMessages(
            messageIdToMessage,
            attributeProvider
        );
 
        //assemble
        Integer actualCount = chunkedAndMarkedMessages.keySet().size();
        Boolean actualFlag = true;
        for (Id messageId : chunkedAndMarkedMessages.keySet()) {
            Message__c actualMessage = chunkedAndMarkedMessages.get(messageId); 
            if (actualMessage.Cause__c != terminateProcess.Name) actualFlag = false;
        }
        
        //assert
        Integer expectedCount = 2;
        System.assertEquals(expectedCount, actualCount);   
        Boolean expectedFlag = true;
        System.assertEquals(expectedFlag, actualFlag);
    }
    
    
    static testmethod void callingGetChunkedAndMarkedMessagesReturnsExpectedCollection02() {
        // Requirement : 
        //       Maximize the number of messages processed in a single context
        // Constraints / Rules
        //       - Messages must all be for the same process 
        //       - find highest number of messages for a single process limited by that 
        //         process's  maximum allowable invocations
        // Scenario : 
        //       - Terminate AND Gate both have the highest allowable invocations 
        //       - Terminate has more  messages than Gate within allowable invocations
        // Expect 
        //      - Return a collection of 2 Terminate messages
        Integer  mockedTerminateCount = 2;   
        Integer  mockedGateCount      = 1;     
        Integer  mockedWiretapCount   = 1;
        Integer totalTerminate =  3;
        Integer totalGate      =  3;
        Integer totalWiretap   =  2;

        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        Process__c gateProcess = ProcessObject.generateOne(Gate.class);
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);

        Map<String,Map<String,Object>> processNameToAttributes = new Map<String,Map<String,Object>>{
            terminateProcess.Name  =>  new Map<String,Object>{
                'Process' => terminateProcess,
                'Limits' => mockedTerminateCount,
                'TotalMessages' => totalTerminate       
            }, 
            gateProcess.Name  =>  new Map<String,Object>{
                'Process' => gateProcess,
                'Limits' => mockedGateCount,
                'TotalMessages' => totalGate      
            },
            wiretapProcess.Name  =>  new Map<String,Object>{
                'Process' => wiretapProcess,
                'Limits' => mockedWiretapCount,
                'TotalMessages' => totalWiretap       
            }     
        };

         // arrange - setup
         Map<String,Object> providerAndMessageIdToMessage = 
            setupProviderAndMessages(processNameToAttributes);
         VerticalBrokerImplementation.IAttributeProvider attributeProvider =   
             (VerticalBrokerImplementation.IAttributeProvider) providerAndMessageIdToMessage.get('Provider');
         Map<Id,Message__c> messageIdToMessage = 
             (Map<Id,Message__c>) providerAndMessageIdToMessage.get('MessageIdToMessage');
    
        //act
        Map<Id,Message__c> chunkedAndMarkedMessages =   VerticalBrokerImplementation.getChunkedAndMarkedMessages(
            messageIdToMessage,
            attributeProvider
        );
 
        //assemble
        Integer actualCount = chunkedAndMarkedMessages.keySet().size();
        Boolean actualFlag = true;
        for (Id messageId : chunkedAndMarkedMessages.keySet()) {
            Message__c actualMessage = chunkedAndMarkedMessages.get(messageId); 
            if (actualMessage.Cause__c != terminateProcess.Name) actualFlag = false;
        }
        
        //assert
        Integer expectedCount = 2;
        System.assertEquals(expectedCount, actualCount);   
        Boolean expectedFlag = true;
        System.assertEquals(expectedFlag, actualFlag);
    }

   static testmethod void callingGetChunkedAndMarkedMessagesReturnsExpectedCollection03() {
        // Requirement : 
        //       Maximize the number of messages processed in a single context
        // Constraints / Rules
        //       - Messages must all be for the same process 
        //       - find highest number of messages for a single process limited by that 
        //         process's  maximum allowable invocations
        // Scenario  : 
        //       - Terminate AND Gate both have the highest allowable invocations 
        //       - Terminate AND Gate  both have same message count allowable invocations
        // Expect 
        //      - Return a collection of 2 Terminate OR 2 Gate messages
        Integer  mockedTerminateCount = 2;   
        Integer  mockedGateCount      = 2;     
        Integer  mockedWiretapCount   = 1;
        Integer totalTerminate =  3;
        Integer totalGate      =  3;
        Integer totalWiretap   =  2;

        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        Process__c gateProcess = ProcessObject.generateOne(Gate.class);
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);

        Map<String,Map<String,Object>> processNameToAttributes = new Map<String,Map<String,Object>>{
            terminateProcess.Name  =>  new Map<String,Object>{
                'Process' => terminateProcess,
                'Limits' => mockedTerminateCount,
                'TotalMessages' => totalTerminate       
            }, 
            gateProcess.Name  =>  new Map<String,Object>{
                'Process' => gateProcess,
                'Limits' => mockedGateCount,
                'TotalMessages' => totalGate      
            },
            wiretapProcess.Name  =>  new Map<String,Object>{
                'Process' => wiretapProcess,
                'Limits' => mockedWiretapCount,
                'TotalMessages' => totalWiretap       
            }     
        };

        // arrange - setup
        Map<String,Object> providerAndMessageIdToMessage = 
            setupProviderAndMessages(processNameToAttributes);
        VerticalBrokerImplementation.IAttributeProvider attributeProvider =   
            (VerticalBrokerImplementation.IAttributeProvider) providerAndMessageIdToMessage.get('Provider');
        Map<Id,Message__c> messageIdToMessage = 
            (Map<Id,Message__c>) providerAndMessageIdToMessage.get('MessageIdToMessage');
    
        //act
        Map<Id,Message__c> chunkedAndMarkedMessages =   VerticalBrokerImplementation.getChunkedAndMarkedMessages(
            messageIdToMessage,
            attributeProvider
        );
 
        //assemble
        Integer actualCount = chunkedAndMarkedMessages.keySet().size();
        Set<String> distinctNames = new Set<String>();
        Set<String> validNames = new Set<String>{
            terminateProcess.Name,
            gateProcess.Name
        };
        Boolean actualFlag = true;
        for (Id messageId : chunkedAndMarkedMessages.keySet()) {
            Message__c actualMessage = chunkedAndMarkedMessages.get(messageId); 
            if(!validNames.contains(actualMessage.Cause__c))  
                actualFlag = false;
            distinctNames.add(actualMessage.Cause__c);
        }
        Integer actualNameCount = distinctNames.size();
        
        //assert
        Integer expectedCount = 2;
        System.assertEquals(expectedCount, actualCount); 
        Integer expectedNameCount = 1;
        System.assertEquals(expectedNameCount, actualNameCount);  
        Boolean expectedFlag = true;
        System.assertEquals(expectedFlag, actualFlag);
   }

   static testmethod void callingGetChunkedAndMarkedMessagesReturnsExpectedCollection04() {
        // Requirement : 
        //       Maximize the number of messages processed in a single context
        // Constraints / Rules
        //       - Messages must all be for the same process 
        //       - find highest number of messages for a single process limited by that 
        //         process's  maximum allowable invocations
        // Scenario  : 
        //       - Gate (5) has a higher allowable invocations value than Terminate (4)
        //       - Terminate (3) has more messages than Gate (2) 
        //       - Terminate  message count (3) with allowable invocations (4)
        // Expect 
        //      - Return a collection of 3 Terminate 
        Integer  mockedTerminateCount = 4;   
        Integer  mockedGateCount      = 5;     
        Integer  mockedWiretapCount   = 1;
        Integer totalTerminate =  3;
        Integer totalGate      =  2;
        Integer totalWiretap   =  2;
        
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        Process__c gateProcess = ProcessObject.generateOne(Gate.class);
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);

        Map<String,Map<String,Object>> processNameToAttributes = new Map<String,Map<String,Object>>{
            terminateProcess.Name  =>  new Map<String,Object>{
                'Process' => terminateProcess,
                'Limits' => mockedTerminateCount,
                'TotalMessages' => totalTerminate       
            }, 
            gateProcess.Name  =>  new Map<String,Object>{
                'Process' => gateProcess,
                'Limits' => mockedGateCount,
                'TotalMessages' => totalGate      
            },
            wiretapProcess.Name  =>  new Map<String,Object>{
                'Process' => wiretapProcess,
                'Limits' => mockedWiretapCount,
                'TotalMessages' => totalWiretap       
            }     
        };

        // arrange - setup
        Map<String,Object> providerAndMessageIdToMessage = 
            setupProviderAndMessages(processNameToAttributes);
        VerticalBrokerImplementation.IAttributeProvider attributeProvider =   
            (VerticalBrokerImplementation.IAttributeProvider) providerAndMessageIdToMessage.get('Provider');
        Map<Id,Message__c> messageIdToMessage = 
            (Map<Id,Message__c>) providerAndMessageIdToMessage.get('MessageIdToMessage');
        
        //act
        Map<Id,Message__c> chunkedAndMarkedMessages =   VerticalBrokerImplementation.getChunkedAndMarkedMessages(
            messageIdToMessage,
            attributeProvider
        );
        
        //assemble
        Integer actualCount = chunkedAndMarkedMessages.keySet().size();
        Set<String> distinctNames = new Set<String>();
        Set<String> validNames = new Set<String>{
        terminateProcess.Name
        };
        Boolean actualFlag = true;
        for (Id messageId : chunkedAndMarkedMessages.keySet()) {
            Message__c actualMessage = chunkedAndMarkedMessages.get(messageId); 
            if(!validNames.contains(actualMessage.Cause__c))  
                actualFlag = false;
            distinctNames.add(actualMessage.Cause__c);
        }
        Integer actualNameCount = distinctNames.size();
        
        //assert
        Integer expectedCount = 3;
        System.assertEquals(expectedCount, actualCount); 
        Integer expectedNameCount = 1;
        System.assertEquals(expectedNameCount, actualNameCount);  
        Boolean expectedFlag = true;
        System.assertEquals(expectedFlag, actualFlag);
    }


   static Map<String,Object> setupProviderAndMessages(Map<String,Map<String,Object>> processNameToAttributes) {
        // parse attributes into collections
        Map<String, Integer> mockedFullyQualifiedClassNameToLimits = new  Map<String, Integer>();
        List<Message__c> messages = new List<Message__c>(); 
        for (String processName : processNameToAttributes.keyset()) {
            Map<String,Object> attributes = processNameToAttributes.get(processName);
            Process__c process = (Process__c) attributes.get('Process');
            Integer Limits = (Integer) attributes.get('Limits');
            Integer totalMessages = (Integer) attributes.get('TotalMessages');
            
            // provider collection
            mockedFullyQualifiedClassNameToLimits.put(processName, Limits);
            
            // message collection
            Integer i = 1;
            while (i <= totalMessages) {
                messages.add(new Message__c( Process__c = process.Id, Cause__c = processName)); 
                i++;
            }
        }
        
        // create provider
        VerticalBrokerImplementation.IAttributeProvider attributeProvider = 
            new VerticalBrokerImplementation.MockAttributeProvider(mockedFullyQualifiedClassNameToLimits);

        // create messages
        insert messages;
        Set<Id> messageIds = new Map<Id,Message__c>(messages).keySet();
        Map<Id,Message__c> messageIdToMessage = new Map<Id,Message__c>([
            SELECT Id, Process__c, Process__r.FullyQualifiedClassName__c, Cause__c 
            FROM Message__c 
            WHERE Id in :messageIds
        ]);
        
        return new Map<String,Object>{
            'Provider' => attributeProvider,
            'MessageIdToMessage' => messageIdToMessage
        };
   }
}