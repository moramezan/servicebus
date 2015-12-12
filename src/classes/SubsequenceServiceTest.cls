@IsTest class SubsequenceServiceTest {
    
    @TestSetup static void testSetup() {
        //act
        new PostInstallHandler().upsertApplication();
        
        //assert
        System.assertNotEquals(null, Application__c.getOrgDefaults().Id, 'Wrong id.');
    }
    
    static testmethod void hasTheCorrectChunks() {
        //arrange
        ApexClassModel.Summary summary = new ApexClassModel.Summary(SubsequenceService.class);
        
        //assert
        Integer expectedChunks = 1; //max sync limit
        Integer actualChunks = summary.Chunks;
        System.assertEquals(expectedChunks, actualChunks);
    }

    static testmethod void withinSystemLimits() {
        Sequence__c origin = new Sequence__c(Name = 'Origin');
        insert origin;
        Step__c originStep = SequenceModel.fromName(origin.Name).appendStep(SubsequenceService.class);
        new StepModel(originStep).upsertConfig();
        
        Sequence__c target = new Sequence__c(Name = 'Target');
        insert target;
        Step__c targetStep = SequenceModel.fromName(target.Name).appendStep(TerminateService.class);
        
        //prepare config in db
        SubsequenceStepConfig__c config = new SubsequenceStepConfig__c(
            Id = originStep.ConfigId__c,
            Sequence__c = 'Target'
        );
        update config;
        
        //assemble
        ApexClassModel.Summary summary = new ApexClassModel.Summary(SubsequenceService.class);
        
        //act
        Test.startTest();
        Integer chunks = summary.Chunks;
        Integer counter = 0;
        for (Integer i = 0; i < chunks; i++) {
            //by reference side effects on inputEvent
            //inside subsequence logic, so new input event for each iteration!
            Map<String,Object> inputEvent = new Map<String,Object>{
                'StepConfigId' => config.Id,
                'Route' => '1#Origin#1'
            };
                
            ApexClassModel.Service service = new SubsequenceService();
            List<Map<String,Object>> outputs = service.handle(inputEvent);
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
        
        SequenceModel.fromId(routine.Id).appendStep(WiretapService.class);
        SequenceModel.fromId(routine.Id).appendStep(WiretapService.class);
        SequenceModel.fromId(routine.Id).appendStep(WiretapService.class);
        SequenceModel.fromId(routine.Id).appendStep(TerminateService.class);
        
        //arrange caller
        Sequence__c caller = new Sequence__c(Name = 'Caller');
        insert caller;
        
        Step__c step1 = SequenceModel.fromId(caller.Id).appendStep(SubsequenceService.class);
        Step__c step2 = SequenceModel.fromId(caller.Id).appendStep(SubsequenceService.class);
        SequenceModel.fromId(caller.Id).appendStep(TerminateService.class);
        
        //arrange config
        Id configId1 = new StepModel(step1).upsertConfig();
        Id configId2 = new StepModel(step2).upsertConfig();
        
        update new SubsequenceStepConfig__c(Id = configId1, Sequence__c = 'Routine');
        update new SubsequenceStepConfig__c(Id = configId2, Sequence__c = 'Routine');
        
        //act (enqueue)
        Test.startTest();
        Job job = new Job('Caller', '00D000000000000AAA');
        System.enqueueJob(job);
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
    
    static testmethod void testSubsequenceNeedsConfig() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        SequenceModel.fromId(sequence.Id).appendStep(SubsequenceService.class);
        SequenceModel.fromId(sequence.Id).appendStep(TerminateService.class);
        
        try {
            //act (no config!)
            ApexClassModel.Service service = new SubsequenceService();
            service.handle(new Map<String,Object>());
            System.assert(false, 'Line above should throw exception.');
        } catch (SubsequenceService.ServiceException e) {
            //assert
            String expectedMessage = 'Null step config id.';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage, 'Wrong message.');
        }
    }

    public class Inserter extends ApexClassModel.Service {
        void callout(Map<String,Object> inputEvent) {}
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            insert new Document(Name = 'Test', FolderId = UserInfo.getUserId());
            return new List<Map<String,Object>>{inputEvent};
        }
    }
    
    public class Error extends ApexClassModel.Service {
        void callout(Map<String,Object> inputEvent) {}
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            Integer i = 1 / 0;
            return null;
        }
    }
    
    static testmethod void testExceptionInSubsequenceGetsCaughtAndRolledBack() {
        //arrange routine
        Sequence__c routine = new Sequence__c(Name = 'Routine');
        insert routine;
        
        SequenceModel.fromId(routine.Id).appendStep(Inserter.class);
        SequenceModel.fromId(routine.Id).appendStep(Error.class);
        
        //arrange caller
        Sequence__c caller = new Sequence__c(Name = 'Caller');
        insert caller;
        
        Step__c step = SequenceModel.fromId(caller.Id).appendStep(SubsequenceService.class);
        SequenceModel.fromId(caller.Id).appendStep(TerminateService.class);
        
        //arrange config
        Id configId = new StepModel(step).upsertConfig();
        update new SubsequenceStepConfig__c(Id = configId, Sequence__c = 'Routine');
        
        //arrange input event
        Map<String,Object> inputEvent = new Map<String,Object>{
            'Route' => '1#Caller#1',
            'StepConfigId' => configId
        };
        
        try {
            //act
            ApexClassModel.Service service = new SubsequenceService();
            service.handle(inputEvent);
            System.assert(false, 'Line above should throw exception.');
        } catch (MathException e) {
            //assert
            String expectedMessage = 'Divide by 0';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage, 'Wrong message.');
        }
    }
    
    @TestVisible class CalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            return new HttpResponse();
        }
    }
    
    public class Callout extends ApexClassModel.Service {
        void callout(Map<String,Object> inputEvent) {
            HttpRequest request = new HttpRequest();
            request.setMethod('GET');
            request.setEndpoint('https://herp.derp/');
            new Http().send(request);
        }
        
        List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
            return new List<Map<String,Object>>{inputEvent};
        }
    }
    
    static testmethod void testCalloutGetsCaughtWithHelpfulMessage() {
        //arrange routine
        Sequence__c routine = new Sequence__c(Name = 'Routine');
        insert routine;
        
        SequenceModel.fromId(routine.Id).appendStep(Callout.class);
        SequenceModel.fromId(routine.Id).appendStep(TerminateService.class);
        
        //arrange caller
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        Step__c step = SequenceModel.fromId(sequence.Id).appendStep(SubsequenceService.class);
        SequenceModel.fromId(sequence.Id).appendStep(TerminateService.class);
        
        //arrange config
        Id configId = new StepModel(step).upsertConfig();
        update new SubsequenceStepConfig__c(Id = configId, Sequence__c = 'Routine');
        
        //arrange input
        Map<String,Object> event = new Map<String,Object>{
            'Route' => '1#Test#1',
            'StepConfigId' => configId,
            'ToSequence' => 'Test'
        };
        
        try {
            //act
            Test.setMock(HttpCalloutMock.class, new CalloutMock());
            ApexClassModel.Service service = new SubsequenceService();
            service.handle(event);
            System.assert(false, 'Line above should throw exception.');
            
        } catch (Broker.ServiceException e) {
            //assert
            String expectedMessage = Callout.class.getName() + ': Callout from subsequence not supported. Consider using jumps instead.';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage, 'Wrong message.');
        }
        
    }
}