@IsTest public class MessageModelTest {
    
    static testmethod void testShowApexClassFindsIt() {
        //arrange sequence and steps
        insert new Sequence__c(Name = 'Test');
        Step__c step = SequenceModel.fromName('Test').appendStep(Terminate.class);
        step.ApexClassId__c = [SELECT Id FROM ApexClass WHERE Name = 'Wiretap'].Id;
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
        String expectedUrl = '/' + [SELECT Id FROM ApexClass WHERE Name = 'Wiretap'].Id;
        String actualUrl = view.getUrl();
        System.assert(expectedUrl.startsWith(actualUrl), 'Wrong URL.');
    }
    
    public class MemoryErrorException extends Exception {}
    
    public class MemoryError extends ApexClassModel.Service {
        void callout(Map<String,Object> inputEvent) {}
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            inputEvent.put('c:OrganizationId', UserInfo.getOrganizationId());
            throw new MemoryErrorException('Something catchable.');
        }
    }
    
    public class MemoryErrorSummary {
        String Description = 'Does stuff in memory, throws an exception not needing rollback.';
        Integer Limits = 1000;
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
        
        for (Integer i = 0; i < 1000; i++) {
            Map<String,Object> event = new Map<String,Object>{'Route' => 'Test#1'};
            Message__c inputMessage = new Message__c();
            inputMessage.Event__c = Json.serialize(event);
            inputMessages.add(inputMessage);
        }
        
        //act and assemble
        Test.startTest();
        Broker.impl().execute(inputMessages, outputMessages);
        Integer dmlStatements = Limits.getDmlStatements();
        Test.stopTest();
        
        //assert
        Integer expectedStatements = 1; //exactly 1 savepoint
        Integer actualStatements = dmlStatements;
        System.assertEquals(expectedStatements, actualStatements, 'Wrong DML count.');
    }
    
    public class InserterErrorException extends Exception {}
    
    public class InserterError extends ApexClassModel.Service {
        void callout(Map<String,Object> inputEvent) {}
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            insert new Document(Name = 'Test.txt', FolderId = UserInfo.getUserId());
            throw new InserterErrorException('Something catchable.');
        }
    }
    
    public class InserterErrorSummary {
        String Description = 'Inserts 1 document, throws an exception needing rollback.';
        Integer Limits = 50;
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
        
        //act
        Test.startTest();
        Broker.impl().execute(inputMessages, outputMessages);
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
    
    public class MemorySummary {
        String Description = 'Does stuff in memory without side effects.';
        Integer Limits = 1000;
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
        
        for (Integer i = 0; i < 1000; i++) {
            Map<String,Object> event = new Map<String,Object>{'Route' => 'Test#1'};
            Message__c inputMessage = new Message__c();
            inputMessage.Event__c = Json.serialize(event);
            inputMessages.add(inputMessage);
        }
        
        //act
        Test.startTest();
        Broker.impl().execute(inputMessages, outputMessages);
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
    
    public class InserterSummary {
        String Description = 'Inserts 1 document, runs 75 times';
        Integer Limits = 75;
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
        
        //act
        Test.startTest();
        Broker.impl().execute(inputMessages, outputMessages);
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
        Step__c step = new Step__c(Name = '1#Test#1', ApexClassName__c = PassThroughService.class.getName(), ConfigId__c = document.Id);
        insert step;
        
        //arrange message
        Map<String,Object> event = new Map<String,Object>{'Route' => '1#Test#1'};
        Message__c message = new Message__c(Event__c = Json.serialize(event));
        MessageModel model = new MessageModel(message);
        
        //act
        List<Message__c> outputMessages = new List<Message__c>();
        model.invokeExecute(outputMessages);
        
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
    
    public class SurpriseNullOutputs extends ApexClassModel.Service {
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
            'Route' => SurpriseNullOutputs.class.getName()
        };
        
        //arrange message
        Message__c message = new Message__c(
            Event__c = Json.serialize(inputEvent)
        );
        
        //act
        MessageModel model = new MessageModel(message);
        List<Message__c> outputMessages = new List<Message__c>();
        model.invokeExecute(outputMessages);
        
        String expectedException = Broker.UserException.class.getName() + ': ' + SurpriseNullOutputs.class.getName() + ': Output event cannot be null';
        String actualException = message.Exception__c;
        System.assertEquals(expectedException, actualException, 'Wrong exception.');
    }
}