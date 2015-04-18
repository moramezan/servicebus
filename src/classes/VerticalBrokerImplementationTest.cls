@IsTest public class VerticalBrokerImplementationTest {
    
    static testmethod void testChunkedMarkContextsCount() {
        //arrange processes and sequence and steps
        Sequence__c sequence = new Sequence__c(Name = 'test');
        insert sequence;
        
        Step__c wiretapStep = StepModel.generateOne(sequence.Name, Wiretap.class.getName());
        Step__c terminateStep = StepModel.generateOne(sequence.Name, Terminate.class.getName());
        
        //arrange messages
        Map<String,Object> parameters = new Map<String,Object>{'__SequenceName' => 'test', '__Position' => 1};
        List<Map<String,Object>> parameterses = new List<Map<String,Object>>{
            parameters,
            parameters,
            parameters,
            parameters,
            parameters,
            parameters,
            parameters,
            parameters,
            parameters
        };
        
        List<Message__c> messages = new Job(parameterses).persist();
        VerticalBrokerImplementation impl = new VerticalBrokerImplementation();
        
        //assert
        Integer expectedContexts = 1000;
        Integer actualContexts = impl.Contexts;
        System.assertEquals(expectedContexts, actualContexts, 'Should have 1000 contexts.');
        
        //act (List controllers are not supported for FieldPermissions)
        Database.QueryLocatorIterator iterator = impl.start(null).iterator();
        List<SObject> records = new List<Sobject>();
        while (iterator.hasNext()) records.add(iterator.next());
        
        //assert
        Integer expectedSize = 1000;
        Integer actualSize = records.size();
        System.assertEquals(expectedSize, actualSize, 'Locator should have 100 records.');
        
        //act
        impl.execute((Database.BatchableContext)Json.deserialize('{}', Database.BatchableContextImpl.class), new List<SObject>());
        
        //assert
        expectedContexts = 999;
        actualContexts = impl.Contexts;
        System.assertEquals(expectedContexts, actualContexts, 'Should have decremented contexts.');
        
        //assert (should have marked as many as he can fit within remaining contexts)
        Integer expectedMarked = 5;
        Integer actualMarked = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Started'];
        System.assertEquals(expectedMarked, actualMarked, 'Should have five marked messages.');
        
        //act
        impl.execute((Database.BatchableContext)Json.deserialize('{}', Database.BatchableContextImpl.class), new List<SObject>());
        
        //assert
        expectedContexts = 998;
        actualContexts = impl.Contexts;
        System.assertEquals(expectedContexts, actualContexts, 'Should have decremented contexts.');
        
        //assert (should have executed all marked messages in one chunk)
        expectedMarked = 0;
        actualMarked = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Started'];
        System.assertEquals(expectedMarked, actualMarked, 'Should have zero marked messages.');
        
        //act
        impl.execute((Database.BatchableContext)Json.deserialize('{}', Database.BatchableContextImpl.class), new List<SObject>());
        
        //assert
        expectedContexts = 997;
        actualContexts = impl.Contexts;
        System.assertEquals(expectedContexts, actualContexts, 'Should have decremented contexts.');
        
        //assert (should have marked as many as he can fit within remaining contexts)
        expectedMarked = 4;
        actualMarked = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Started'];
        System.assertEquals(expectedMarked, actualMarked, 'Should have four marked messages.');
        
        //act
        impl.execute((Database.BatchableContext)Json.deserialize('{}', Database.BatchableContextImpl.class), new List<SObject>());
        
        //assert
        expectedContexts = 996;
        actualContexts = impl.Contexts;
        System.assertEquals(expectedContexts, actualContexts, 'Should have decremented contexts.');
        
        //assert (should have executed all marked messages in one chunk)
        expectedMarked = 0;
        actualMarked = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Started'];
        System.assertEquals(expectedMarked, actualMarked, 'Should have zero marked messages.');
        
        //act
        impl.execute((Database.BatchableContext)Json.deserialize('{}', Database.BatchableContextImpl.class), new List<SObject>());
        
    }

    static testmethod void testMarkAndExecuteAndDoneConditions() {
        //arrange specific broker implementation
        insert new BrokerSetting__c(BrokerClassName__c = VerticalBrokerImplementation.class.getName());
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange steps
        Step__c step = StepModel.generateOne(sequence.Name, Terminate.class.getName());
        
        //arrange message
        new Job(
            new Map<String,Object> {
                '__SequenceName' => 'TestSequence',
                '__Position' => 1
            }
        ).persist();
        
        //act (enqueue)
        VerticalBrokerImplementation impl = (VerticalBrokerImplementation)Broker.impl();
        
        //assert
        Integer expectedCount = 1;
        Integer actualCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Buffered'];
        System.assertEquals(expectedCount, actualCount, 'Message should be buffered.');
        
        //act (mark)
        List<SObject> scopes = new List<SObject>();
        impl.execute((Database.BatchableContext)Json.deserialize('{}', Database.BatchableContextImpl.class), scopes);
        
        //assert
        expectedCount = 1;
        actualCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Started'];
        System.assertEquals(expectedCount, actualCount, 'Message should be started.');
        System.assert(!impl.abortJob, 'Job should not be aborted.');
        
        //act (execute)
        Id messageId = [SELECT Id FROM Message__c WHERE Status__c = 'Started'].Id;
        System.debug(ApexDomain.getById(step.Id));
        impl.execute((Database.BatchableContext)Json.deserialize('{}', Database.BatchableContextImpl.class), scopes);
        
        //assert
        expectedCount = 1;
        actualCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Completed'];
        System.assertEquals(expectedCount, actualCount, 'Message should be completed.');
        System.assert(!impl.abortJob, 'Job should not be aborted.');
        
        //act (done)
        impl.execute((Database.BatchableContext)Json.deserialize('{}', Database.BatchableContextImpl.class), scopes);
        System.assert(impl.abortJob, 'Job should be aborted.');
    }

    static testmethod void testMarkLimitedToTotalPotentialMarksWhenBufferedMessagesGtTotalPotentialMarks() {
        //arrange specific broker implementation
        insert new BrokerSetting__c(BrokerClassName__c = VerticalBrokerImplementation.class.getName());
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange steps
        Step__c step = StepModel.generateOne(sequence.Name, Terminate.class.getName());
        
        //arrange messages
        new Job(
            new Map<String,Object> {
                '__SequenceName' => 'TestSequence',
                '__Position' => 1
            }
        ).persist();
            
        new Job(
            new Map<String,Object> {
                '__SequenceName' => 'TestSequence',
                '__Position' => 1
            }
        ).persist();
        
        new Job(
            new Map<String,Object> {
                '__SequenceName' => 'TestSequence',
                '__Position' => 1
            }
        ).persist();
        
        Integer totalPotentialMarks = 3; // Less than Buffered Messages Count
        
        
        //arrange resolution
        VerticalBrokerImplementation impl = (VerticalBrokerImplementation)Broker.impl();
        Integer actualBufferedCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Buffered'];
        
        //act
        List<SObject> scopes = new List<SObject>();
        impl.execute((Database.BatchableContext)Json.deserialize('{}', Database.BatchableContextImpl.class), scopes);
        
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
        insert new BrokerSetting__c(BrokerClassName__c = VerticalBrokerImplementation.class.getName());
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange steps
        Step__c step = StepModel.generateOne(sequence.Name, Terminate.class.getName());
        
        //arrange messages
        new Job(
            new Map<String,Object> {
                '__SequenceName' => 'TestSequence',
                '__Position' => 1
            }
        ).persist();
            
        new Job(
            new Map<String,Object> {
                '__SequenceName' => 'TestSequence',
                '__Position' => 1
            }
        ).persist();
        
        new Job(
            new Map<String,Object> {
                '__SequenceName' => 'TestSequence',
                '__Position' => 1
            }
        ).persist();
        
        Integer totalPotentialMarks = 4;  // Greater than Buffered Messages Count

        //arrange resolution
        VerticalBrokerImplementation impl = (VerticalBrokerImplementation)Broker.impl();
        Integer actualBufferedCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Buffered'];
        
        //act
        List<SObject> scopes = new List<SObject>();
        impl.execute((Database.BatchableContext)Json.deserialize('{}', Database.BatchableContextImpl.class), scopes);
        
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

}