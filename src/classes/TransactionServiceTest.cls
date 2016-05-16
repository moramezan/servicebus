@IsTest class TransactionServiceTest {
    
    @TestSetup static void testSetup() {
        //act
        new PostInstallHandler().onInstall(null);
        
        //assert
        System.assertNotEquals(null, Application__c.getOrgDefaults().Id, 'Wrong id.');
    }
    
    static testmethod void hasTheCorrectChunks() {
        //arrange
        ApexClassModel.Definition definition = new ApexClassModel.Definition(TransactionService.class);
        
        //assert
        Integer expectedChunks = 1; //max sync limit
        Integer actualChunks = definition.Chunks;
        System.assertEquals(expectedChunks, actualChunks);
    }

    static testmethod void withinSystemLimits() {
        Sequence__c origin = new Sequence__c(Name = 'Origin');
        insert origin;
        Step__c originStep = SequenceModel.fromName(origin.Name).appendStep(TransactionService.class.getName());
        new StepModel(originStep).upsertConfig();
        
        Sequence__c target = new Sequence__c(Name = 'Target');
        insert target;
        Step__c targetStep = SequenceModel.fromName(target.Name).appendStep(TerminateService.class.getName());
        
        //prepare config in db
        TransactionStepConfig__c config = new TransactionStepConfig__c(
            Id = originStep.ConfigId__c,
            Sequence__c = 'Target'
        );
        update config;
        
        //assemble
        ApexClassModel.Definition definition = new ApexClassModel.Definition(TransactionService.class);
        
        //act
        Test.startTest();
        Integer chunks = definition.Chunks;
        Integer counter = 0;
        for (Integer i = 0; i < chunks; i++) {
            //by reference side effects on inputEvent
            //inside transaction logic, so new input event for each iteration!
            Map<String,Object> inputEvent = new Map<String,Object>{
                'StepConfigId' => config.Id,
                'Route' => '1#Origin#1'
            };
                
            ApexClassModel.Service service = new TransactionService();
            List<Map<String,Object>> outputs = service.execute(inputEvent);
            counter++;
        }
        Test.stopTest();

        //assert
        System.assertEquals(chunks, counter, 'Chunks not reached.');
    }
    
    static testmethod void testRoutineExecutesSynchronously() {
        //arrange routine
        Sequence__c routine = new Sequence__c(Name = 'Routine');
        insert routine;
        
        SequenceModel.fromId(routine.Id).appendStep(DebugService.class.getName());
        SequenceModel.fromId(routine.Id).appendStep(DebugService.class.getName());
        SequenceModel.fromId(routine.Id).appendStep(DebugService.class.getName());
        SequenceModel.fromId(routine.Id).appendStep(TerminateService.class.getName());
        
        //arrange caller
        Sequence__c caller = new Sequence__c(Name = 'Caller');
        insert caller;
        
        Step__c step1 = SequenceModel.fromId(caller.Id).appendStep(TransactionService.class.getName());
        Step__c step2 = SequenceModel.fromId(caller.Id).appendStep(TransactionService.class.getName());
        SequenceModel.fromId(caller.Id).appendStep(TerminateService.class.getName());
        
        //arrange config
        Id configId1 = new StepModel(step1).upsertConfig();
        Id configId2 = new StepModel(step2).upsertConfig();
        
        update new TransactionStepConfig__c(Id = configId1, Sequence__c = 'Routine');
        update new TransactionStepConfig__c(Id = configId2, Sequence__c = 'Routine');
        
        //act (enqueue)
        Test.startTest();
        Enqueue.invoke(new Map<String,Object>{'ToSequence' => 'Caller'});
        Test.stopTest();
        
        //assert
        Integer expectedBefore = 0;
        Integer actualBefore = Limits.getEmailInvocations();
        System.assertEquals(expectedBefore, actualBefore, 'Wrong before.');
        
        //act (execute)
        Broker.impl().run();
        
        //assert
        Integer expectedAfter = 6;
        Integer actualAfter = Limits.getEmailInvocations();
        System.assertEquals(expectedAfter, actualAfter, 'Wrong after.');
    }
    
    static testmethod void testTransactionNeedsConfig() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        SequenceModel.fromId(sequence.Id).appendStep(TransactionService.class.getName());
        SequenceModel.fromId(sequence.Id).appendStep(TerminateService.class.getName());
        
        try {
            //act (no config!)
            ApexClassModel.Service service = new TransactionService();
            service.execute(new Map<String,Object>());
            System.assert(false, 'Line above should throw exception.');
        } catch (TransactionService.ServiceException e) {
            //assert
            String expectedMessage = 'Null step config id.';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage, 'Wrong message.');
        }
    }

    public class Inserter extends ApexClassModel.Service {
        override public List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            insert new Document(Name = 'Test', FolderId = UserInfo.getUserId());
            return new List<Map<String,Object>>{inputEvent};
        }
    }
    
    public class Error extends ApexClassModel.Service {
        override public List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            Integer i = 1 / 0;
            return null;
        }
    }
    
    static testmethod void testExceptionInTransactionGetsCaughtAndRolledBack() {
        //arrange routine
        Sequence__c routine = new Sequence__c(Name = 'Routine');
        insert routine;
        
        SequenceModel.fromId(routine.Id).appendStep(Inserter.class.getName());
        SequenceModel.fromId(routine.Id).appendStep(Error.class.getName());
        
        //arrange caller
        Sequence__c caller = new Sequence__c(Name = 'Caller');
        insert caller;
        
        Step__c step = SequenceModel.fromId(caller.Id).appendStep(TransactionService.class.getName());
        SequenceModel.fromId(caller.Id).appendStep(TerminateService.class.getName());
        
        //arrange config
        Id configId = new StepModel(step).upsertConfig();
        update new TransactionStepConfig__c(Id = configId, Sequence__c = 'Routine');
        
        //arrange input event
        Map<String,Object> inputEvent = new Map<String,Object>{
            'Route' => '1#Caller#1',
            'StepConfigId' => configId
        };
        
        Savepoint savepoint;
        
        try {
            
            savepoint = Database.setSavepoint();
            
            //act
            ApexClassModel.Service service = new TransactionService();
            service.execute(inputEvent);
            System.assert(false, 'Line above should throw exception.');
            
        } catch (MathException e) {
            
            Database.rollback(savepoint);
            
            //assert
            String expectedMessage = 'Divide by 0';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage, 'Wrong message.');
            
            Integer expectedSize = 0;
            Integer actualSize = [SELECT COUNT() FROM Document WHERE Name = 'Test'];
            System.assertEquals(expectedSize, actualSize, 'Wrong size.');
        }
    }
    
    @TestVisible class CalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            return new HttpResponse();
        }
    }
    
    public class Callout extends ApexClassModel.Service {
        override public void callout(Map<String,Object> inputEvent) {
            HttpRequest request = new HttpRequest();
            request.setMethod('GET');
            request.setEndpoint('https://herp.derp/');
            new Http().send(request);
        }
        
        override public List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            return new List<Map<String,Object>>{inputEvent};
        }
    }
    
    static testmethod void testCalloutGetsCaughtWithHelpfulMessage() {
        //arrange routine
        Sequence__c routine = new Sequence__c(Name = 'Routine');
        insert routine;
        
        SequenceModel.fromId(routine.Id).appendStep(Callout.class.getName());
        SequenceModel.fromId(routine.Id).appendStep(TerminateService.class.getName());
        
        //arrange caller
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        Step__c step = SequenceModel.fromId(sequence.Id).appendStep(TransactionService.class.getName());
        SequenceModel.fromId(sequence.Id).appendStep(TerminateService.class.getName());
        
        //arrange config
        Id configId = new StepModel(step).upsertConfig();
        update new TransactionStepConfig__c(Id = configId, Sequence__c = 'Routine');
        
        //arrange input
        Map<String,Object> event = new Map<String,Object>{
            'Route' => '1#Test#1',
            'StepConfigId' => configId,
            'ToSequence' => 'Test'
        };
        
        try {
            //act
            Test.setMock(HttpCalloutMock.class, new CalloutMock());
            ApexClassModel.Service service = new TransactionService();
            service.execute(event);
            System.assert(false, 'Line above should throw exception.');
            
        } catch (Broker.ServiceException e) {
            //assert
            String expectedMessage = Callout.class.getName() + ': Callout from transaction not supported. Consider using jumps instead.';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage, 'Wrong message.');
        }
        
    }
    
    public class Split extends ApexClassModel.Service {
        override public List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            return new List<Map<String,Object>>{inputEvent.clone(), inputEvent.clone(), inputEvent.clone()};
        }
    }
    
    //per #1182
    static testmethod void testTerminateEventsTranscendTransaction() {
        
        //arrange main sequence
        insert new Sequence__c(Name = 'Test');
        SequenceModel.fromName('Test').appendStep(TransactionService.class.getName());
        SequenceModel.fromName('Test').appendStep(TerminateService.class.getName());
        
        //arrange config
        Id stepConfigId = StepModel.fromName('1#Test#1').upsertConfig();
        update new TransactionStepConfig__c(Id = stepConfigId, Sequence__c = 'Sub');
        
        //arrange sub sequence
        insert new Sequence__c(Name = 'Sub');
        SequenceModel.fromName('Sub').appendStep(Split.class.getName());
        SequenceModel.fromName('Sub').appendStep(TerminateService.class.getName());
        
        //act
        Map<String,Object> inputEvent = new Map<String,Object>{'Route' => '1#Test#1', 'StepConfigId' => stepConfigId};
        List<Map<String,Object>> outputEvents = new TransactionService().execute(inputEvent);
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
        
        //assemble
        List<Object> terminateEvents = (List<Object>)outputEvents[0].get('TerminateEvents');
        
        //assert
        expectedSize = 3;
        actualSize = terminateEvents.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
    }
}