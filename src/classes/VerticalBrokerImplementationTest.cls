@IsTest public class VerticalBrokerImplementationTest {
    
    @TestSetup static void testSetup() {
        OAuthSetting__c setting = OAuthSetting__c.getOrgDefaults();
        setting.RunningUserId__c = UserInfo.getUserId();
        upsert setting;
    }
    
    static testmethod void testChunkedMarkContextsCount() {
        //arrange processes and sequence and steps
        Sequence__c sequence = new Sequence__c(Name = 'test');
        insert sequence;
        
        Step__c wiretapStep = SequenceModel.fromName(sequence.Name).appendStep(Wiretap.class);
        Step__c terminateStep = SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
        
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
        Integer expectedContexts = 50;
        Integer actualContexts = impl.Contexts;
        System.assertEquals(expectedContexts, actualContexts, 'Wrong contexts.');
        
        //act (start up big query locator)
        Database.QueryLocatorIterator iterator = impl.start(null).iterator();
        List<SObject> records = new List<Sobject>();
        while (iterator.hasNext()) records.add(iterator.next());
        
        //assert
        Integer expectedSize = 50;
        Integer actualSize = records.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
        
        //act (persist none and mark as many as he can fit within remaining contexts)
        impl.execute(null, new List<SObject>());
        
        //assert
        expectedContexts = 49;
        actualContexts = impl.Contexts;
        System.assertEquals(expectedContexts, actualContexts, 'Wrong contexts.');
        
        //assert
        Integer expectedMarked = 5;
        Integer actualMarked = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Started'];
        System.assertEquals(expectedMarked, actualMarked, 'Wrong marked.');
        
        //act (execute the marked guys and move them out of property)
        impl.execute(null, new List<SObject>());
        
        //assert
        expectedContexts = 48;
        actualContexts = impl.Contexts;
        System.assertEquals(expectedContexts, actualContexts, 'Wrong contexts.');
        
        //assert
        Integer expectedPersistable = 10; //5 inputs 5 outputs (unless there were exceptions!)
        Integer actualPersistable = impl.persistableMessages.size();
        System.assertEquals(expectedPersistable, actualPersistable, 'Wrong persistable.');
        
        //act (persist previous and mark as many as he can fit within remaining contexts)
        impl.execute(null, new List<SObject>());
        
        //assert
        expectedContexts = 47;
        actualContexts = impl.Contexts;
        System.assertEquals(expectedContexts, actualContexts, 'Wrong contexts.');
        
        //assert
        expectedMarked = 4;
        actualMarked = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Started'];
        System.assertEquals(expectedMarked, actualMarked, 'Wrong marked.');
        
        //act (execute the marked guys and move them out of property)
        impl.execute(null, new List<SObject>());
        
        //assert
        expectedContexts = 46;
        actualContexts = impl.Contexts;
        System.assertEquals(expectedContexts, actualContexts, 'Wrong contexts.');
        
        //assert
        expectedPersistable = 8; //4 inputs 4 outputs (unless there were exceptions!)
        actualPersistable = impl.persistableMessages.size();
        System.assertEquals(expectedPersistable, actualPersistable, 'Wrong persistable.');
        
        //act (persist previous and mark as many as he can fit within remaining contexts)
        impl.execute(null, new List<SObject>());
        
        //assert
        expectedContexts = 45;
        actualContexts = impl.Contexts;
        System.assertEquals(expectedContexts, actualContexts, 'Wrong contexts.');
        
        //assert
        expectedMarked = 9;
        actualMarked = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Started'];
        System.assertEquals(expectedMarked, actualMarked, 'Wrong marked.');
        
        //act (execute the marked guys and move them out of property)
        impl.execute(null, new List<SObject>());
        
        //assert
        expectedContexts = 44;
        actualContexts = impl.Contexts;
        System.assertEquals(expectedContexts, actualContexts, 'Wrong contexts.');
        
        //assert
        expectedPersistable = 9; //9 inputs 0 outputs
        actualPersistable = impl.persistableMessages.size();
        System.assertEquals(expectedPersistable, actualPersistable, 'Wrong persistable.');
    }

    static testmethod void testMarkAndExecuteAndDoneConditions() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange steps
        Step__c step = SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
        
        //arrange message
        new Job(
            new Map<String,Object> {
                '__SequenceName' => 'TestSequence',
                '__Position' => 1
            }
        ).persist();
        
        //act (enqueue)
        VerticalBrokerImplementation impl = new VerticalBrokerImplementation();
        
        //assert
        Integer expectedCount = 1;
        Integer actualCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Buffered'];
        System.assertEquals(expectedCount, actualCount, 'Wrong count.');
        
        //act (persist any and mark as many as he can fit within remaining contexts)
        impl.execute(null, new List<SObject>());
        
        //assert
        expectedCount = 1;
        actualCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Started'];
        System.assertEquals(expectedCount, actualCount, 'Message should be marked.');
        System.assert(!impl.abortJob, 'Job should not be aborted.');
        
        //act (execute the marked guys and move them out of property)
        impl.execute(null, new List<SObject>());
        
        //assert
        Integer expectedPersistable = 1; //1 input 0 outputs (terminate)
        Integer actualPersistable = impl.persistableMessages.size();
        System.assertEquals(expectedCount, actualCount, 'Wrong persistable.');
        System.assert(!impl.abortJob, 'Job should not be aborted.');
        
        //act (abort condition)
        impl.execute(null, new List<SObject>());
        System.assert(impl.abortJob, 'Job should be aborted.');
    }

    static testmethod void testMarkLimitedToTotalPotentialMarksWhenBufferedMessagesGtTotalPotentialMarks() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange steps
        Step__c step = SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
        
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
        VerticalBrokerImplementation impl = new VerticalBrokerImplementation();
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
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange steps
        Step__c step = SequenceModel.fromName(sequence.Name).appendStep(Terminate.class);
        
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
        VerticalBrokerImplementation impl = new VerticalBrokerImplementation();
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
}