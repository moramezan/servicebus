@IsTest public class MessageModelTest {
    
    static testmethod void testShowApexClassFindsIt() {
        //arrange sequence and steps
        insert new Sequence__c(Name = 'Test');
        Step__c step = SequenceModel.fromName('Test').appendStep(Terminate.class);
        step.ApexClassId__c = [SELECT Id FROM ApexClass WHERE Name = 'Wiretap'].Id;
        update step;
        
        //arrange message
        Message__c message = new Message__c(
            Step__c = 'Test#1',
            Event__c = '{"__SequenceName":"Test","__Position":1}'
        );
        
        //act
        MessageModel model = new MessageModel(message);
        PageReference view = model.showApexClass();
        
        //assert
        String expectedUrl = '/' + [SELECT Id FROM ApexClass WHERE Name = 'Wiretap'].Id;
        String actualUrl = view.getUrl();
        System.assert(expectedUrl.startsWith(actualUrl), 'Wrong URL.');
    }
    
    public class MissingToString {}
    
    static testmethod void testInvokeCalloutsFailureWhenMissingToString() {
        //arrange message
        Message__c message = new Message__c();
        message.Event__c = '{}';
        
        //arrange model
        MessageModel model = new MessageModel(message);
        model.Reflector = MissingToString.class;
        model.Process = new MissingToString();
        
        //act
        model.invokeCallouts();
        
        //assert
        String expectedException = MissingToString.class.getName() + ': ' + 'ESB Process must extend Abstract.ESB';
        String actualException = message.Exception__c;
        System.assertEquals(expectedException, actualException, 'Wrong exception.');
    }
    
    static testmethod void testInvokeExecuteFailureWhenMissingToString() {
        //arrange message
        Message__c message = new Message__c();
        message.Event__c = '{}';
        
        //arrange model
        MessageModel model = new MessageModel(message);
        model.Reflector = MissingToString.class;
        model.Process = new MissingToString();
        
        //act
        model.invokeExecute(new List<Message__c>());
        
        //assert
        String expectedException = MissingToString.class.getName() + ': ' + 'ESB Process must extend Abstract.ESB';
        String actualException = message.Exception__c;
        System.assertEquals(expectedException, actualException, 'Wrong exception.');
    }
    
    public class NullReturnValue extends ApexClassModel.BaseProcess {
        
        override protected void callouts(Map<String,Object> inputEvent) {
            //base process returns null
        }
    
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            return null;
        }
        
    }
    
    static testmethod void testInvokeCalloutsSuccessWhenNullReturnValue() {
        //arrange message
        Message__c message = new Message__c();
        message.Event__c = '{}';
        
        //arrange model
        MessageModel model = new MessageModel(message);
        model.Reflector = NullReturnValue.class;
        model.Process = new NullReturnValue();
        
        //act
        model.invokeCallouts();
        
        //assert
        String unexpectedException = null;
        String actualException = message.Exception__c;
        System.assertEquals(unexpectedException, actualException, 'Wrong exception.');
    }
    
    static testmethod void testInvokeExecuteFailureWhenNullReturnValue() {
        //arrange message
        Message__c message = new Message__c();
        message.Event__c = '{}';
        
        //arrange model
        MessageModel model = new MessageModel(message);
        model.Reflector = NullReturnValue.class;
        model.Process = new NullReturnValue();
        
        //act
        model.invokeExecute(new List<Message__c>());
        
        //assert
        String expectedException = NullReturnValue.class.getName() + ': ' + ' Return type of an ESB Process must be a List<Map<String,Object>>';
        String actualException = message.Exception__c;
        System.assertEquals(expectedException, actualException, 'Wrong exception.');
    }
    
    public class GoodReturnValue extends ApexClassModel.BaseProcess {
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            return new List<Map<String,Object>>();
        }
    }
    
    static testmethod void testInvokeCalloutsSuccessWhenGoodReturnValue() {
        //arrange message
        Message__c message = new Message__c();
        message.Event__c = '{}';
        
        //arrange model
        MessageModel model = new MessageModel(message);
        model.Reflector = GoodReturnValue.class;
        model.Process = new GoodReturnValue();
        
        //act
        model.invokeCallouts();
        
        //assert
        String expectedException = null;
        String actualException = message.Exception__c;
        System.assertEquals(expectedException, actualException, 'Wrong exception.');
    }
    
    static testmethod void testInvokeExecuteSuccessWhenGoodReturnValue() {
        //arrange message
        Message__c message = new Message__c();
        message.Event__c = '{}';
        
        //arrange model
        MessageModel model = new MessageModel(message);
        model.Reflector = GoodReturnValue.class;
        model.Process = new GoodReturnValue();
        
        //act
        model.invokeCallouts();
        
        //assert
        String expectedException = null;
        String actualException = message.Exception__c;
        System.assertEquals(expectedException, actualException, 'Wrong exception.');
    }
    
    public class MemoryErrorException extends Exception {}
    
    public class MemoryError extends ApexClassModel.BaseProcess {
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            inputEvent.put('c__OrganizationId', UserInfo.getOrganizationId());
            throw new MemoryErrorException('Something catchable.');
        }
    }
    
    public class MemoryErrorESB extends ApexClassModel.BaseSummary {
        String Description = 'Does stuff in memory, throws an exception not needing rollback.';
        Integer Limits = 1000;
    }
    
    static testmethod void testRollbackTaxRelievedOnMemoryProcess() {
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
            Message__c inputMessage = new Message__c();
            inputMessage.Step__c = 'Test#1';
            inputMessage.Event__c = '{}';
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
    
    public class InserterError extends ApexClassModel.BaseProcess {
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            insert new Document(Name = 'Test.txt', FolderId = UserInfo.getUserId());
            throw new InserterErrorException('Something catchable.');
        }
    }
    
    public class InserterErrorESB extends ApexClassModel.BaseSummary {
        String Description = 'Inserts 1 document, throws an exception needing rollback.';
        Integer Limits = 50;
    }
    
    static testmethod void testRollbackTaxImposedOnDmlProcess() {
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
            Message__c inputMessage = new Message__c();
            inputMessage.Step__c = 'Test#1';
            inputMessage.Event__c = '{}';
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
    
    public class Memory extends ApexClassModel.BaseProcess {
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            inputEvent.put('c__OrganizationId', UserInfo.getOrganizationId());
            return new List<Map<String,Object>>();
        }
    }
    
    public class MemoryESB extends ApexClassModel.BaseSummary {
        String Description = 'Does stuff in memory without side effects.';
        Integer Limits = 1000;
    }
    
    static testmethod void testSavepointTaxRelievedOnMemoryProcess() {
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
            Message__c inputMessage = new Message__c();
            inputMessage.Step__c = 'Test#1';
            inputMessage.Event__c = '{}';
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
    
    public class Inserter extends ApexClassModel.BaseProcess {
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            Map<String,Object> outputEvent = inputEvent.clone();
            insert new Document(Name = 'Test.txt', FolderId = UserInfo.getUserId());
            return new List<Map<String,Object>>();
        }
    }
    
    public class InserterESB extends ApexClassModel.BaseSummary {
        String Description = 'Inserts 1 document, runs 75 times';
        Integer Limits = 75;
    }
    
    static testmethod void testSavepointTaxImposedOnDmlProcess() {
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
            Message__c inputMessage = new Message__c();
            inputMessage.Step__c = 'Test#1';
            inputMessage.Event__c = '{}';
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
}