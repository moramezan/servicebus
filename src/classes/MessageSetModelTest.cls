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
    
    static testmethod void testUnpopulatedJsonFields() {
        //arrange message
        Message__c message = new Message__c(
            Event__c = '{"__IsHeartbeatProcess":true}'
        );
        
        //act
        new MessageSetModel(new List<Message__c>{message}).populateJsonFields();
        
        //assert
        String expectedRoute = null;
        String actualRoute = message.Step__c;
        System.assertEquals(expectedRoute, actualRoute, 'Route should be null for heartbeats.');
    }
    
    static testmethod void testPopulateJsonFields() {
        //arrange message
        Message__c message = new Message__c(
            Event__c = '{"__SequenceName":"test","__Position":1}'
        );
        
        //act
        new MessageSetModel(new List<Message__c>{message}).populateJsonFields();
        
        //assert
        String expectedRoute = 'test#1';
        String actualRoute = message.Step__c;
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
    
    static testmethod void callingSwallowToStringCorrectlySwallowsToStringOnTrace() {
        //arrange message
        String cause =
                '{' + '\n' +
                        '"LineNumber" : 11,' + '\n' +
                        '"Message" : "null input to JSON parser",' + '\n' +
                        '"StackTraceString" : "(System Code)\nClass.BaseProcess.toString: line 18, column 1\nClass.Broker.Wrapper.invokeMain: line 340, column 1\nClass.Broker.execute: line 597, column 1\nClass.VerticalBrokerImplementation.execute: line 128, column 1\nExternal entry point\nClass.VerticalBrokerDispatcher.execute: line 13, column 1",' + '\n' +
                        '"TypeName" : "System.NullPointerException",' + '\n' +
                        '"Cause" : null' + '\n' +
                        '}';
        Message__c message = new Message__c(
                Cause__c = cause
        );

        //act
        new MessageSetModel(new List<Message__c>{message}).swallowToString();

        //assert
        String expectedCause =
                '{' + '\n' +
                '"LineNumber" : 11,' + '\n' +
                '"Message" : "null input to JSON parser",' + '\n' +
                '"StackTraceString" : "(System Code)\nClass.Broker.Wrapper.invokeMain: line 340, column 1\nClass.Broker.execute: line 597, column 1\nClass.VerticalBrokerImplementation.execute: line 128, column 1\nExternal entry point\nClass.VerticalBrokerDispatcher.execute: line 13, column 1",' + '\n' +
                '"TypeName" : "System.NullPointerException",' + '\n' +
                '"Cause" : null' + '\n' +
                '}';
        String actualCause = message.Cause__c;
        System.assertEquals(expectedCause, actualCause, 'Cause should not contain a reference to toString');
    }


    
     static testmethod void callingPopulateJsonFieldsCorrectlyPopulatesQueueableId() {
         //arrange message
         String queueableId = '123456';
         Message__c message = new Message__c(
             Event__c = '{"__QueueableId":"' + queueableId + '"}'
         );

         //act
         new MessageSetModel(new List<Message__c>{message}).populateJsonFields();

         //assert

         String actualQueueableId = message.QueueableId__c;
         String expectedQueueableId = queueableId;
         System.assertEquals(expectedQueueableId, actualQueueableId, 'Failed to populate QueueableId');
     }
    
     static testmethod void callingPopulateJsonFieldsCorrectlyPopulatesEntryPointUuid() {
         //arrange message
         String EntryPointUuid = '123456';
         Message__c message = new Message__c(
             Event__c = '{"esb__EntryPointUuid":"' + entryPointUuid + '"}'
         );

         //act
         new MessageSetModel(new List<Message__c>{message}).populateJsonFields();

         //assert

         String actualEntryPointUuid = message.EntryPointUuid__c;
         String expectedEntryPointUuid = EntryPointUuid;
         System.assertEquals(expectedEntryPointUuid, actualEntryPointUuid, 'Failed to populate EntryPointUuid');
     }
     
    static testmethod void testKillRequiresSelectedMessages() {
        try {
            //act
            new MessageSetModel(new List<Message__c>()).kill();
            System.assert(false, 'Above should throw exception');
        } catch (MessageSetModel.MessageException e) {
            //assert
            String expectedMessage = 'You must select some messages.';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage, 'Wrong message.');
        }
    }
    
    static testmethod void testKillComplainsAboutUnkillableMessages() {
        //arrange messages
        Message__c message = new Message__c(
            Status__c = 'Paused',
            Event__c = '{}'
        );
        insert message;
        
        try {
            //act
            new MessageSetModel(new List<Message__c>{message}).kill();
            System.assert(false, 'Above should throw exception.');
        } catch (MessageSetModel.MessageException e) {
            String expectedMessage = 'Only messages with an Exception can be killed.';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage, 'Wrong message.');
        }
        
    }
    
    static testmethod void testKillMarksMessagesWithCompletedStatus() {
        //arrange message
        Message__c message = new Message__c(
            Status__c = 'Started',
            Exception__c = 'Some problem'
        );
        insert message;
        
        //act
        new MessageSetModel(new List<Message__c>{message}).kill();
        
        //assemble
        message = [SELECT Status__c FROM Message__c WHERE Id = :message.Id];
        
        //assert
        String expectedStatus = 'Completed';
        String actualStatus = message.Status__c;
        System.assertEquals(expectedStatus, actualStatus, 'Wrong status.');
    }
    
    static testmethod void  callingDoPauseOnPausedMessagesPausesQueue() {
        //assert
        System.assert(!BrokerSetting__c.getOrgDefaults().IsPaused__c, 'Wrong flag before.');
        
        //act
        MessageSetModel.pauseQueue();
        
        //assert
        System.assert(BrokerSetting__c.getOrgDefaults().IsPaused__c, 'Wrong flag after.');
    }
    
    static testmethod void  callingDoResumeOnQueuedMessagesEnqueuesWakeup() {
        //arrange broker
        BrokerSetting__c setting = BrokerSetting__c.getOrgDefaults();
        setting.IsPaused__c = true;
        upsert setting;
        
        //arrange message
        insert new Message__c(Status__c = 'Paused', Event__c = '{}');
        
        //assert
        System.assert(BrokerSetting__c.getOrgDefaults().IsPaused__c, 'Wrong flag before.');
        
        Integer expectedBefore = 1;
        Integer actualBefore = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Paused'];
        System.assertEquals(expectedBefore, actualBefore, 'Wrong count after.');
        
        //act
        MessageSetModel.resumeQueue();
        
        //assert
        System.assert(!BrokerSetting__c.getOrgDefaults().IsPaused__c, 'Wrong flag after.');
        
        Integer expectedAfter = 1;
        Integer actualAfter = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Buffered'];
        System.assertEquals(expectedAfter, actualAfter, 'Wrong count after.');
    }
}