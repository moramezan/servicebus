@IsTest public class JobTest {
    
    //TODO needs more tests
    
    static testmethod void testSimpleEventConstructor() {
        //arrange
        String sequenceName = 'TestSequence';
        String recordId = UserInfo.getOrganizationId();
        
        //act
        Test.startTest();
        Job job = new Job(sequenceName, recordId);
        System.enqueueJob(job);
        Test.stopTest();
        
        //assemble
        List<Message__c> messages = [SELECT Id, Event__c FROM Message__c];
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = messages.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong number of messages.');
        
        //assemble
        Map<String,Object> event = (Map<String,Object>)Json.deserializeUntyped(messages[0].Event__c);
        
        //assert
        System.assert(event.containsKey('__Hops'));
        System.assert(event.containsKey('__EnqueueUserId'));
        System.assert(event.containsKey('__EntryPointUuid'));
        System.assert(event.containsKey('__EntryPointDatetime'));
        System.assert(event.containsKey('esb__RecordId'));
        System.assert(event.containsKey('esb__SequenceName'));
        System.assert(event.containsKey('esb__EnqueueUserId'));
        System.assert(event.containsKey('esb__EntryPointUuid'));
        System.assert(event.containsKey('esb__EntryPointDatetime'));
    }

}