@IsTest class MessageSetModelTest {
    
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
        //arrange input
        Map<String,Object> inputEvent = new Map<String,Object>{
            'Route' => Router.class.getName()
        };
        
        //arrange message
        Message__c message = new Message__c(
            Event__c = Json.serialize(inputEvent)
        );
        
        //act
        new MessageSetModel(new List<Message__c>{message}).persist(new List<Message__c>());
        new MessageSetModel(new List<Message__c>{message}).alphabetizeJsonAndPopulateFields();
        
        //assert
        String expectedRoute = Router.class.getName();
        String actualRoute = message.Route__c;
        System.assertEquals(expectedRoute, actualRoute, 'Route should be raw service for heartbeats.');
    }
    
    static testmethod void testPopulateJsonFields() {
        //arrange message
        Map<String,Object> event = new Map<String,Object>{'Route' => '1#Test#1'};
        Message__c message = new Message__c(
            Event__c = Json.serialize(event)
        );
        
        //act
        new MessageSetModel(new List<Message__c>{message}).alphabetizeJsonAndPopulateFields();
        
        //assert
        String expectedRoute = '1#Test#1';
        String actualRoute = message.Route__c;
        System.assertEquals(expectedRoute, actualRoute, 'Route incorrectly populated.');
    }
    
    static testmethod void testValidMessageParameters() {
        //arrange message
        Map<String,Object> event = new Map<String,Object>{'Route' => '1#Test#1'};
        Message__c validMessage = new Message__c(
            Event__c = Json.serialize(event)
        );
        
        //assert
        System.assert(!ApexPages.hasMessages(), 'Should not have errors before.');
        
        //act
        new MessageSetModel(new List<Message__c>{validMessage}).alphabetizeJsonAndPopulateFields();
        
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
        new MessageSetModel(new List<Message__c>{validMessage}).alphabetizeJsonAndPopulateFields();
        
        //assert
        System.assert(ApexPages.hasMessages(), 'Should have errors after.');
    }
    
    static testmethod void callingSwallowToStringCorrectlySwallowsToStringOnTrace() {
        //arrange message
        String cause = 'Class.DoCallout.callout: line 12, column 1'
            + '\n(servicebus)'
            + '\n(abstract)'
            + '\n(esb)'
        ;
        
        Message__c message = new Message__c(
                Cause__c = cause
        );

        //act
        new MessageSetModel(new List<Message__c>{message}).swallowToString();
        
        //assert
        String expectedCause = 'Class.DoCallout.callout: line 12, column 1';
        String actualCause = message.Cause__c;
        System.assertEquals(expectedCause, actualCause, 'Cause should not contain a reference to toString');
    }


    
     static testmethod void callingPopulateJsonFieldsCorrectlyPopulatesJobId() {
         //arrange message
         Id jobId = UserInfo.getUserId();
         Message__c message = new Message__c(
             Event__c = '{"JobId":"' + jobId + '"}'
         );

         //act
         new MessageSetModel(new List<Message__c>{message}).alphabetizeJsonAndPopulateFields();

         //assert

         Id expectedJobId = jobId;
         Id actualJobId = message.JobId__c;
         System.assertEquals(expectedJobId, actualJobId, 'Failed to populate JobId');
     }
    
     static testmethod void callingPopulateJsonFieldsCorrectlyPopulatesCorrelationUuid() {
         //arrange message
         String CorrelationUuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx';
         Message__c message = new Message__c(
             Event__c = '{"CorrelationUuid":"' + correlationUuid + '"}'
         );

         //act
         new MessageSetModel(new List<Message__c>{message}).alphabetizeJsonAndPopulateFields();

         //assert

         String actualCorrelationUuid = message.CorrelationUuid__c;
         String expectedCorrelationUuid = CorrelationUuid;
         System.assertEquals(expectedCorrelationUuid, actualCorrelationUuid, 'Failed to populate CorrelationUuid');
     }
     
    static testmethod void testKillRequiresSelectedMessages() {
        try {
            //act
            new MessageSetModel(new List<Message__c>()).kill();
            System.assert(false, 'Above should throw exception');
        } catch (MessageSetModel.ModelException e) {
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
        } catch (MessageSetModel.ModelException e) {
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
        System.assert(!Application__c.getOrgDefaults().BrokerPaused__c, 'Wrong flag before.');
        
        //act
        MessageSetModel.pauseQueue();
        
        //assert
        System.assert(Application__c.getOrgDefaults().BrokerPaused__c, 'Wrong flag after.');
    }
    
    static testmethod void  callingDoResumeOnQueuedMessagesEnqueuesWakeup() {
        //arrange broker
        Application__c application = Application__c.getOrgDefaults();
        application.BrokerPaused__c = true;
        upsert application;
        
        //arrange message
        insert new Message__c(Status__c = 'Paused', Event__c = '{}');
        
        //assert
        System.assert(Application__c.getOrgDefaults().BrokerPaused__c, 'Wrong flag before.');
        
        Integer expectedBefore = 1;
        Integer actualBefore = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Paused'];
        System.assertEquals(expectedBefore, actualBefore, 'Wrong count after.');
        
        //act
        MessageSetModel.resumeQueue();
        
        //assert
        System.assert(!Application__c.getOrgDefaults().BrokerPaused__c, 'Wrong flag after.');
        
        Integer expectedAfter = 1;
        Integer actualAfter = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Buffered'];
        System.assertEquals(expectedAfter, actualAfter, 'Wrong count after.');
    }
    
    static testmethod void testTriggerStripsOurSecretParameters() {
        //arrange input
        Map<String,Object> inputEvent = new Map<String,Object>{
            'Herp' => 'Derp',
            'Range' => 50,
            'Chunk' => 1,
            'AllowsCallouts' => false
        };
        
        //arrange message
        Message__c message = new Message__c(
            Event__c = Json.serialize(inputEvent)
        );
        
        //act
        insert message;
        
        //assemble
        message = [SELECT Event__c FROM Message__c];
        
        //assert
        System.assert(!message.Event__c.contains('Range'), 'Should not contain range.');
        System.assert(!message.Event__c.contains('Chunk'), 'Should not contain chunk.');
        System.assert(!message.Event__c.contains('AllowsCallouts'), 'Should not contain allows callouts.');
        
    }
    
    static testmethod void testMessageIdUpdatedOnEvent() {
        //arrange message
        Message__c message = new Message__c(Event__c = '{}');
        insert message;
        
        //act
        new MessageSetModel(new List<Message__c>{message}).mark('0000');
        
        //assemble
        message = [SELECT Event__c FROM Message__c];
        
        //assert
        Id expectedId = message.Id;
        String actualEvent = message.Event__c;
        System.assert(actualEvent.contains(expectedId), 'Event should contain message id.');
    }
}