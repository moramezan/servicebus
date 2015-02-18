@IsTest public class JobTest {

    static testmethod void testSimpleEventConstructor() {
        //arrange
        String sequenceName = 'TestSequence';
        String entityId = UserInfo.getOrganizationId();
        
        //act
        Job j = new Job(sequenceName, entityId);
        
        //assemble
        List<Message__c> messages = j.messages;
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = messages.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong number of messages.');
        
        //assemble
        Map<String,Object> event = (Map<String,Object>)Json.deserializeUntyped(messages[0].Parameters__c);
        
        //assert
        System.assert(event.containsKey('__Hops'));
        System.assert(event.containsKey('__EnqueueUserId'));
        System.assert(event.containsKey('__EntryPointUuid'));
        System.assert(event.containsKey('__EntryPointDatetime'));
        System.assert(event.containsKey('esb__Id'));
        System.assert(event.containsKey('esb__SequenceName'));
        System.assert(event.containsKey('esb__EnqueueUserId'));
        System.assert(event.containsKey('esb__EntryPointUuid'));
        System.assert(event.containsKey('esb__EntryPointDatetime'));
    }

}