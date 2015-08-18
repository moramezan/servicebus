@IsTest public class JobTest {
    
    //TODO needs more tests
    
    static testmethod void testSimpleEventConstructor() {
        //arrange
        String sequenceName = 'Test';
        String recordId = UserInfo.getOrganizationId();
        
        //act
        Test.startTest();
        Job job = new Job(sequenceName, recordId);
        
        System.assert(job.Events[0].containsKey('Sequence'));
        
        System.enqueueJob(job);
        Test.stopTest();
        
        //assert
        
        //assemble
        List<Message__c> messages = [SELECT Id, Event__c FROM Message__c];
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = messages.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong number of messages.');
        
        //assemble
        Map<String,Object> event = (Map<String,Object>)Json.deserializeUntyped(messages[0].Event__c);
        
        //assert
        System.assert(event.containsKey('Hops'));
        System.assert(event.containsKey('EntryPointTimestamp'));
        System.assert(event.containsKey('RecordId'));
        System.assert(event.containsKey('Route'));
        System.assert(event.containsKey('EnqueuedById'));
        System.assert(event.containsKey('EntryPointUuid'));
    }
    
    static testmethod void testUnpersistableTypesDetectedInConstructor() {
        //arrange
        Map<String,Object> input = new Map<String,Object>{
            'naughty' => Terminate.class
        };
        
        try {
            //act
            new Job(input);
            System.assert(false, 'Line above should throw exception');
        } catch (Exception e) {
            //assert
            String expectedMessage = 'Type unsupported in JSON: common.apex.runtime.bytecode.BytecodeApexObjectType';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage);
        }
    }
    
    static testmethod void testEnoughDmlRowsToEnqueueManyEvents() {
        //arrange input events
        List<Map<String,Object>> inputEvents = new List<Map<String,Object>>();
        for (Integer i = 0; i < 10000; i++) inputEvents.add(new Map<String,Object>());
        
        //assert
        Integer expectedBefore = 0;
        Integer actualBefore = Limits.getDmlRows();
        System.assertEquals(expectedBefore, actualBefore, 'Wrong size.');

        //act
        Job job = new Job(inputEvents);
        job.execute(null);
        
        //assert
        Integer expectedLimit = 10000;
        Integer actualLimit = Limits.getLimitDmlRows();
        System.assertEquals(expectedLimit, actualLimit, 'Wrong size.');
        
        Integer expectedAfter = 10000;
        Integer actualAfter = Limits.getDmlRows();
        System.assertEquals(expectedAfter, actualAfter, 'Wrong size.');
    }
    
    static testmethod void testTooManyEventsDetectedInConstructor() {
        //arrange input events
        List<Map<String,Object>> inputEvents = new List<Map<String,Object>>();
        for (Integer i = 0; i < 10001; i++) inputEvents.add(new Map<String,Object>());
        
        try {
            //act
            new Job(inputEvents);
            System.assert(false, 'Line above should throw exception.');
        } catch (Exception e) {
            //assert
            String expectedMessage = 'Too many events: 10001';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage, 'Wrong message.');
        }
        
    }
    
}