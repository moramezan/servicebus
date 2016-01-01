@IsTest class MessageModelTest {

    @TestSetup static void testSetup() {
        //act
        new PostInstallHandler().onInstall(null);
        
        //assert
        System.assertNotEquals(null, Application__c.getOrgDefaults().Id, 'Wrong id.');
    }
    
    static testmethod void testShowApexClassFindsIt() {
        //arrange sequence and steps
        insert new Sequence__c(Name = 'Test');
        Step__c step = SequenceModel.fromName('Test').appendStep(TerminateService.class);
        step.ApexClassId__c = [SELECT Id FROM ApexClass WHERE Name = 'WiretapService' AND NamespacePrefix = :Application__c.getOrgDefaults().Prefix__c].Id;
        update step;
        
        //arrange message
        Map<String,Object> event = new Map<String,Object>{'Route' => '1#Test#1'};
        Message__c message = new Message__c(
            Event__c = Json.serialize(event)
        );
        
        //act
        MessageModel model = new MessageModel(message);
        PageReference view = model.showApexClass();
        
        //assert
        String expectedUrl = '/' + [SELECT Id FROM ApexClass WHERE Name = 'WiretapService' AND NamespacePrefix = :Application__c.getOrgDefaults().Prefix__c].Id;
        String actualUrl = view.getUrl();
        System.assert(expectedUrl.startsWith(actualUrl), 'Wrong URL.');
    }
    
    public class MemoryError extends ApexClassModel.Service {
        void callout(Map<String,Object> inputEvent) {}
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            inputEvent.put('c:OrganizationId', UserInfo.getOrganizationId());
            Integer i = 1 / 0;
            return null;
        }
    }
    
    public class MemoryErrorSummary extends ApexClassModel.Summary {
        String Description = 'Does stuff in memory, throws an exception not needing rollback.';
        Integer Chunks = 200;
    }
    
    static testmethod void testRollbackTaxRelievedOnMemoryService() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        //arrange step
        SequenceModel model = SequenceModel.fromId(sequence.Id);
        model.appendStep(MemoryError.class);
        
        //arrange messages
        List<Message__c> inputMessages = new List<Message__c>();
        List<Message__c> outputMessages = new List<Message__c>();
        
        for (Integer i = 0; i < 200; i++) {
            Map<String,Object> event = new Map<String,Object>{'Route' => '1#Test#1'};
            Message__c inputMessage = new Message__c();
            inputMessage.Event__c = Json.serialize(event);
            inputMessages.add(inputMessage);
        }
        
        //persist
        insert inputMessages;
        new MessageSetModel(inputMessages).mark('0000');
        
        //act and assemble
        Test.startTest();
        outputMessages = new MessageSetModel(inputMessages).execute(null);
        Integer dmlStatements = Limits.getDmlStatements();
        Test.stopTest();
        
        //assert
        Integer expectedStatements = 1; //exactly 1 savepoint
        Integer actualStatements = dmlStatements;
        System.assertEquals(expectedStatements, actualStatements, 'Wrong DML count.');
    }
    
    public class InserterError extends ApexClassModel.Service {
        void callout(Map<String,Object> inputEvent) {}
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            insert new Document(Name = 'Test.txt', FolderId = UserInfo.getUserId());
            Integer i = 1 / 0;
            return null;
        }
    }
    
    public class InserterErrorSummary extends ApexClassModel.Summary {
        String Description = 'Inserts 1 document, throws an exception needing rollback.';
        Integer Chunks = 50;
    }
    
    static testmethod void testRollbackTaxImposedOnDmlService() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        //arrange steps
        SequenceModel model = SequenceModel.fromId(sequence.Id);
        model.appendStep(InserterError.class);
        
        //arrange messages
        List<Message__c> inputMessages = new List<Message__c>();
        List<Message__c> outputMessages = new List<Message__c>();
        
        for (Integer i = 0; i < 50; i++) {
            Map<String,Object> event = new Map<String,Object>{'Route' => '1#Test#1'};
            Message__c inputMessage = new Message__c();
            inputMessage.Event__c = Json.serialize(event);
            inputMessages.add(inputMessage);
        }
        
        //persist
        insert inputMessages;
        new MessageSetModel(inputMessages).mark('0000');
        
        //act
        Test.startTest();
        outputMessages = new MessageSetModel(inputMessages).execute(null);
        Integer dmlStatements = Limits.getDMLStatements();
        Test.stopTest();
        
        //assert
        Integer expectedStatements = 150; //50 savepoints, 50 documents, 50 rollbacks
        Integer actualStatements = dmlStatements;
        System.assertEquals(expectedStatements, actualStatements, 'Wrong DML count.');
    }
    
    public class Memory extends ApexClassModel.Service {
        void callout(Map<String,Object> inputEvent) {}
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            inputEvent.put('c:OrganizationId', UserInfo.getOrganizationId());
            return new List<Map<String,Object>>();
        }
    }
    
    public class MemorySummary extends ApexClassModel.Summary {
        String Description = 'Does stuff in memory without side effects.';
        Integer Chunks = 200;
    }
    
    static testmethod void testSavepointTaxRelievedOnMemoryService() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        //arrange steps
        SequenceModel model = SequenceModel.fromId(sequence.Id);
        model.appendStep(Memory.class);
        
        //arrange messages
        List<Message__c> inputMessages = new List<Message__c>();
        List<Message__c> outputMessages = new List<Message__c>();
        
        for (Integer i = 0; i < 200; i++) {
            Map<String,Object> event = new Map<String,Object>{'Route' => '1#Test#1'};
            Message__c inputMessage = new Message__c();
            inputMessage.Event__c = Json.serialize(event);
            inputMessages.add(inputMessage);
        }
        
        //persist
        insert inputMessages;
        new MessageSetModel(inputMessages).mark('0000');
        
        //act
        Test.startTest();
        outputMessages = new MessageSetModel(inputMessages).execute(null);
        Integer dmlStatements = Limits.getDMLStatements();
        Test.stopTest();
        
        //assert
        Integer expectedStatements = 1; //exactly 1 savepoint
        Integer actualStatements = dmlStatements;
        System.assertEquals(expectedStatements, actualStatements, 'Wrong DML count.');
    }
    
    public class Inserter extends ApexClassModel.Service {
        void callout(Map<String,Object> inputEvent) {}
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            Map<String,Object> outputEvent = inputEvent.clone();
            insert new Document(Name = 'Test.txt', FolderId = UserInfo.getUserId());
            return new List<Map<String,Object>>();
        }
    }
    
    public class InserterSummary extends ApexClassModel.Summary {
        String Description = 'Inserts 1 document, runs 75 times';
        Integer Chunks = 75;
    }
    
    static testmethod void testSavepointTaxImposedOnDmlService() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        //arrange step
        SequenceModel model = SequenceModel.fromId(sequence.Id);
        model.appendStep(Inserter.class);
        
        //arrange messages
        List<Message__c> inputMessages = new List<Message__c>();
        List<Message__c> outputMessages = new List<Message__c>();
        
        for (Integer i = 0; i < 75; i++) {
            Map<String,Object> event = new Map<String,Object>{'Route' => '1#Test#1'};
            Message__c inputMessage = new Message__c();
            inputMessage.Event__c = Json.serialize(event);
            inputMessages.add(inputMessage);
        }
        
        //persist
        insert inputMessages;
        new MessageSetModel(inputMessages).mark('0000');
        
        //act
        Test.startTest();
        outputMessages = new MessageSetModel(inputMessages).execute(null);
        Integer dmlStatements = Limits.getDMLStatements();
        Test.stopTest();
        
        //assert
        Integer expectedStatements = 150; //75 savepoints, 75 documents
        Integer actualStatements = dmlStatements;
        System.assertEquals(expectedStatements, actualStatements, 'Wrong DML count.');
    }
    
    public class PassThroughService extends ApexClassModel.Service {
        void callout(Map<String,Object> inputEvent) {}
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            return new List<Map<String,Object>>{inputEvent};
        }
    }
    
    static testmethod void testStepConfigIdGetsPopulated() {
        //arrange config
        Document document = new Document(Name = 'Config', FolderId = UserInfo.getUserId());
        insert document;
        
        //arrange step
        Step__c step = new Step__c(Name = '1#Test#1', ApexTypeName__c = PassThroughService.class.getName(), ConfigId__c = document.Id);
        insert step;
        
        //arrange message
        Map<String,Object> event = new Map<String,Object>{'Route' => '1#Test#0'}; //incremented in persist
        Message__c message = new Message__c(Event__c = Json.serialize(event));
        
        //act
        List<Message__c> outputMessages = new List<Message__c>{message};
        new MessageSetModel(new List<Message__c>()).persist(outputMessages);
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = outputMessages.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
        
        //assemble
        Map<String,Object> outputEvent = (Map<String,Object>)Json.deserializeUntyped(outputMessages[0].Event__c);
        
        //assert
        Id expectedStepConfigId = document.Id;
        Id actualStepConfigId = (Id)outputEvent.get('StepConfigId');
        System.assertEquals(expectedStepConfigId, actualStepConfigId, 'Wrong step config id.');
    }
    
    //SurpriseNullOutputs
    public class SNO extends ApexClassModel.Service {
        void callout(Map<String,Object> inputEvent) {}
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            return new List<Map<String,Object>>{
                new Map<String,Object>{'herp' => 'derp'},
                null,
                new Map<String,Object>{'foo' => 'bar'}
            };
        }
    }
    
    static testmethod void testNullEventsReturned() {
        //arrange input
        Map<String,Object> inputEvent = new Map<String,Object>{
            'Route' => SNO.class.getName()
        };
        
        //arrange message
        Message__c message = new Message__c(
            Event__c = Json.serialize(inputEvent)
        );
        
        //act
        MessageModel model = new MessageModel(message);
        List<Message__c> outputMessages = new List<Message__c>();
        model.invokeExecute(outputMessages);
        
        String expectedException = Broker.ServiceException.class.getName() + ': ' + SNO.class.getName() + ': Output event cannot be null';
        String actualException = message.Exception__c;
        System.assertEquals(expectedException, actualException, 'Wrong exception.');
    }
    
    static testmethod void testParentIdPopulated() {
        //arrange sequence
        insert new Sequence__c(Name = 'Test');
        
        //arrange step
        SequenceModel.fromName('Test').appendStep(WiretapService.class);
        
        //arrange event
        Map<String,Object> inputEvent = new Map<String,Object>{
            'Route' => '1#Test#1'
        };
        
        //arrange message
        Message__c message = new Message__c(
            Event__c = Json.serialize(inputEvent)
        );
        
        //act
        insert message;
        List<Message__c> outputMessages = new List<Message__c>();
        new MessageModel(message).invokeExecute(outputMessages);
        
        //assert
        Id expectedParentId = message.Id;
        Id actualParentId = outputMessages[0].ParentId__c;
        System.assertEquals(expectedParentId, actualParentId, 'Wrong parent id.');
    }
    
    static testmethod void testRoute() {
        //arrange
        Map<String,Object> outputEvent;
        Object expectedParam;
        Object actualParam;
        
        //act
        outputEvent = new Map<String,Object>{'ToSequence' => 'Test'};
        ApexClassModel.route(outputEvent);
        
        //assert
        expectedParam = '1#Test#1';
        actualParam = outputEvent.get('Route');
        System.assertEquals(expectedParam, actualParam, 'Wrong param.');
        
        expectedParam = 'Test';
        actualParam = outputEvent.get('servicebus:ToSequence');
        System.assertEquals(expectedParam, actualParam, 'Wrong param.');
        
        //act
        outputEvent = new Map<String,Object>{'ToService' => 'WiretapService'};
        ApexClassModel.route(outputEvent);
        
        //assert
        expectedParam = 'WiretapService';
        actualParam = outputEvent.get('Route');
        System.assertEquals(expectedParam, actualParam, 'Wrong param.');
        
        expectedParam = 'WiretapService';
        actualParam = outputEvent.get('servicebus:ToService');
        System.assertEquals(expectedParam, actualParam, 'Wrong param.');
        
        //arrange
        Document document = new Document(Name = 'Config', FolderId = UserInfo.getUserId());
        insert document;
        
        Step__c step = new Step__c(Name = '1#Test#1', Version__c = 1, Sequence__c = 'Test', Position__c = 1, ConfigId__c = document.Id);
        insert step;
        
        //act
        outputEvent = new Map<String,Object>{'ToConfigIds' => new Set<Id>{document.Id}};
        ApexClassModel.route(outputEvent);
        
        //assert
        expectedParam = '1#Test#1';
        actualParam = outputEvent.get('Route');
        System.assertEquals(expectedParam, actualParam, 'Wrong param.');
        
        expectedParam = new Set<Id>{document.Id};
        actualParam = outputEvent.get('servicebus:ToConfigIds');
        System.assertEquals(expectedParam, actualParam, 'Wrong param.');
    }
    
    static testmethod void testNormalRouteIncrements() {
        //arrange
        Map<String,Object> outputEvent = new Map<String,Object>();
        
        //act
        outputEvent.put('Route', '1#Test#2');
        ApexClassModel.route(outputEvent);
        
        //assert
        String expectedRoute = '1#Test#3';
        String actualRoute = (String)outputEvent.get('Route');
        System.assertEquals(expectedRoute, actualRoute, 'Wrong route.');
        
    }
    
    static testmethod void testHelperRouteOverwrites() {
        //arrange
        Map<String,Object> outputEvent = new Map<String,Object>();
        
        //act (for sequence)
        outputEvent.put('Route', 'Incorrect');
        outputEvent.put('ToSequence', 'Test');
        ApexClassModel.route(outputEvent);
        
        //assert
        String expectedRoute = '1#Test#1';
        String actualRoute = (String)outputEvent.get('Route');
        System.assertEquals(expectedRoute, actualRoute, 'Wrong route.');
        
        //act (for service)
        outputEvent.put('Route', 'Incorrect');
        outputEvent.put('ToService', 'TerminateService');
        ApexClassModel.route(outputEvent);
        
        expectedRoute = 'TerminateService';
        actualRoute = (String)outputEvent.get('Route');
        System.assertEquals(expectedRoute, actualRoute, 'Wrong route.');
        
        //act (for config);
        Application__c application = Application__c.getOrgDefaults();
        application.RouterVersion__c = 2;
        upsert application;
        insert new Step__c(Name = '2#Test#1', Version__c = 2, Sequence__c = 'Test', Position__c = 1, ConfigId__c = '00D000000000000');
        outputEvent.put('Route', 'Incorrect');
        outputEvent.put('ToConfigIds', new Set<Id>{'00D000000000000'});
        ApexClassModel.route(outputEvent);
        
        expectedRoute = '2#Test#1';
        actualRoute = (String)outputEvent.get('Route');
        System.assertEquals(expectedRoute, actualRoute, 'Wrong route.');
    }
    
    static testmethod void testIncomingMessageStampedWithCorrectVersion() {
        //arrange
        Application__c application = Application__c.getOrgDefaults();
        application.RouterVersion__c = 9;
        upsert application;
        
        //arrange
        Map<String,Object> outputEvent = new Map<String,Object>();
        
        //act
        outputEvent.put('ToSequence', 'Test');
        ApexClassModel.route(outputEvent);
        
        //assert
        String expectedRoute = '9#Test#1';
        String actualRoute = (String)outputEvent.get('Route');
        System.assertEquals(expectedRoute, actualRoute, 'Wrong route.');
    }
    
    static testmethod void testCantRestartBuffered() {
        Id messageId;
        
        //arrange
        messageId = Database.insert(new Message__c(Status__c = 'Buffered')).getId();
        
        try {
            //act
            MessageModel.fromId(messageId).restart();
            System.assert(false, 'Line above should throw exception.');
        } catch (Exception e) {
            //assert
            String expectedMessage = 'Only Paused or Exception messages can be restarted.';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage, 'Wrong message.');
        }
        
        //arrange
        messageId = Database.insert(new Message__c(Status__c = 'Completed')).getId();
        
        try {
            //act
            MessageModel.fromId(messageId).restart();
            System.assert(false, 'Line above should throw exception.');
        } catch (Exception e) {
            //assert
            String expectedMessage = 'Only Paused or Exception messages can be restarted.';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage, 'Wrong message.');
        }
        
        //arrange
        messageId = Database.insert(new Message__c(Status__c = 'Started')).getId();
        
        try {
            //act
            MessageModel.fromId(messageId).restart();
            System.assert(false, 'Line above should throw exception.');
        } catch (Exception e) {
            //assert
            String expectedMessage = 'Only Paused or Exception messages can be restarted.';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage, 'Wrong message.');
        }
    }
    
    static testmethod void testRestartExecutesAndPersists() {
        //arrange
        Message__c message = new Message__c(
            Status__c = 'Started',
            Exception__c = 'Exception',
            Event__c = '{"Route":"' + WiretapService.class.getName() + '"}'
        );
        insert message;
        
        //act
        MessageModel.fromId(message.Id).restart();
        
        //assert
        Integer expectedCount = 1;
        Integer actualCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Completed' ALL ROWS];
        System.assertEquals(expectedCount, actualCount, 'Wrong message');
    }
    
}