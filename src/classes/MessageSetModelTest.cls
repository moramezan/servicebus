@IsTest public class MessageSetModelTest {
    
    static testmethod void inhibitCreationFromGuiInhibitsGui() {
        //arrange
        Message__c message = (Message__c)Message__c.SObjectType.newSObject(null, true);
        
        try {
            //act
            MessageSetModel.Inhibit = true;
            Database.insert(message);
            MessageSetModel.Inhibit = false;
            System.assert(false, 'Above should throw exception first');
        } catch (DmlException e) {
            //assert
            String expectedMessage = 'Messages cannot be created from the GUI.';
            String actualMessage = e.getDmlMessage(0);
            System.assertEquals(expectedMessage, actualMessage, 'Wrong message');
        }
    }
    
    static testmethod void inhibitCreationFromGuiAllowsApexApi() {
        //arrange
        Message__c message = (Message__c)Message__c.SObjectType.newSObject(null, true);
        
        //act
        MessageSetModel.Inhibit = false;
        Database.SaveResult result = Database.insert(message);
        MessageSetModel.Inhibit = true;
        
        //assert
        System.assert(result.isSuccess(), 'Should be successful');
    }
    
    static testmethod void testUnpopulatedRouteKey() {
        //arrange message
        Message__c message = new Message__c(
            Event__c = '{"__IsHeartbeatProcess":true}'
        );
        
        //act
        new MessageSetModel(new List<Message__c>{message}).populateRouteKey();
        
        //assert
        String expectedRoute = null;
        String actualRoute = message.Route__c;
        System.assertEquals(expectedRoute, actualRoute, 'Route should be null for heartbeats.');
    }
    
    static testmethod void testPopulateRouteKey() {
        //arrange message
        Message__c message = new Message__c(
            Event__c = '{"__SequenceName":"test","__Position":1}'
        );
        
        //act
        new MessageSetModel(new List<Message__c>{message}).populateRouteKey();
        
        //assert
        String expectedRoute = 'test#1';
        String actualRoute = message.Route__c;
        System.assertEquals(expectedRoute, actualRoute, 'Route incorrectly populated.');
    }
    
    static testmethod void testValidMessageParameters() {
        //arrange message
        Message__c validMessage = new Message__c(
            Event__c = '{"__SequenceName":"test","__Position":1}'
        );
        
        //assert
        System.assert(!ApexPages.hasMessages(), 'Should not have errors before.');
        
        //act
        new MessageSetModel(new List<Message__c>{validMessage}).validateJsonParameters();
        
        //assert
        System.assert(!ApexPages.hasMessages(), 'Should not have errors after.');
    }
    
    static testmethod void testInvalidMessageParameters() {
        //arrange message
        Message__c validMessage = new Message__c(
            Event__c = '{...}'
        );
        
        //assert
        System.assert(!ApexPages.hasMessages(), 'Should not have errors before.');
        
        //act
        new MessageSetModel(new List<Message__c>{validMessage}).validateJsonParameters();
        
        //assert
        System.assert(ApexPages.hasMessages(), 'Should have errors after.');
    }
    
    static testmethod void testOneRecordOverflowIsManaged() {
        //arrange maximum
        MessageSetModel.MaxTotalMessages = 10;
        
        //arrange 10 dummy data
        List<Message__c> messages = new List<Message__c>();
        for (Integer i = 0; i < 10; i++) messages.add(new Message__c(Status__c = 'Completed'));
        insert messages;
        MessageSetModel.IsCleaned = false;
        
        //assert
        Integer expectedCount = 10;
        Integer actualCount = [SELECT COUNT() FROM Message__c];
        System.assertEquals(expectedCount, actualCount, 'All records should remain so far.');
        
        //act 1 more
        insert new Message__c(Status__c = 'Completed');
        
        //assert
        expectedCount = 10;
        actualCount = [SELECT COUNT() FROM Message__c];
        System.assertEquals(expectedCount, actualCount, 'Overflow should have culled one.');
    }
    
    static testmethod void testTwentyRecordOverflowIsManaged()
    {
        //arrange maximum
        MessageSetModel.MaxTotalMessages = 10;
        
        //arrange 10 dummy data
        List<Message__c> messages = new List<Message__c>();
        for (Integer i = 0; i < 10; i++) messages.add(new Message__c(Status__c = 'Completed'));
        insert messages;
        MessageSetModel.IsCleaned = false;
        
        //assert
        Integer expectedCount = 10;
        Integer actualCount = [SELECT COUNT() FROM Message__c];
        System.assertEquals(expectedCount, actualCount, 'All records should remain so far.');
        
        //act 20 more
        messages = new List<Message__c>();
        for (Integer i = 0; i < 20; i++) messages.add(new Message__c(Status__c = 'Completed'));
        insert messages;
        
        //assert
        expectedCount = 10;
        actualCount = [SELECT COUNT() FROM Message__c];
        System.assertEquals(expectedCount, actualCount, 'Overflow should have culled twenty.');
    }
    
    static testmethod void testOverflowManagerRunsOnceOnly()
    {
        //arrange maximum
        MessageSetModel.MaxTotalMessages = 5;
        
        //arrange 5 dummy data
        List<Message__c> messages = new List<Message__c>();
        for (Integer i = 0; i < 5; i++) messages.add(new Message__c(Status__c = 'Completed'));
        insert messages;
        MessageSetModel.IsCleaned = false;
        
        //assert
        Integer expectedCount = 5;
        Integer actualCount = [SELECT COUNT() FROM Message__c];
        System.assertEquals(expectedCount, actualCount, 'All records should remain so far.');
        
        //act 1 more
        insert new Message__c(Status__c = 'Completed');
        
        //assert
        expectedCount = 5;
        actualCount = [SELECT COUNT() FROM Message__c];
        System.assertEquals(expectedCount, actualCount, 'Overflow should have culled one.');
        
        //act 1 more
        insert new Message__c(Status__c = 'Completed');
        
        //assert
        expectedCount = 6;
        actualCount = [SELECT COUNT() FROM Message__c];
        System.assertEquals(expectedCount, actualCount, 'Overflow manager should only run once per context!');
    }
}