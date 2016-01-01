@IsTest class JumpServiceTest {
    
    @TestSetup static void testSetup() {
        //act
        new PostInstallHandler().onInstall(null);
        
        //assert
        System.assertNotEquals(null, Application__c.getOrgDefaults().Id, 'Wrong id.');
    }
    
    static testmethod void hasTheCorrectChunks() {
        //arrange
        ApexClassModel.Summary summary = new ApexClassModel.Summary(JumpService.class);
        
        //assert
        Integer expectedChunks = 200; //max sync limit
        Integer actualChunks = summary.Chunks;
        System.assertEquals(expectedChunks, actualChunks);
    }


   static testmethod void withinSystemLimits() {
        //arrange
        ApexClassModel.Summary summary = new ApexClassModel.Summary(JumpService.class);
        
        //arrange
        Sequence__c target = new Sequence__c(Name = 'Target');
        insert target;
        SequenceModel.fromName(target.Name).appendStep(TerminateService.class.getName());
        
        JumpStepConfig__c config = new JumpStepConfig__c(Name = target.Id, Sequence__c = 'Target');
        insert config;
        
        Sequence__c origin = new Sequence__c(Name = 'Origin');
        insert origin;
        SequenceModel.fromName(origin.Name).appendStep(JumpService.class.getName());
        SequenceModel.fromName(origin.Name).appendStep(TerminateService.class.getName());
        
        
        Map<String,Object> inputEvent = new Map<String,Object>{
            'StepConfigId' => config.Id,
            'Route' => '1#Origin#1',
            'data' => 'herpderp'
        };


        //act
        Test.startTest();
        Integer chunks = summary.Chunks;
        Integer counter = 0;
        for (Integer i = 0; i < chunks; i++) {
            ApexClassModel.Service service = new JumpService();
            List<Map<String,Object>> outputs = service.handle(inputEvent);
            counter++;
        }
        Test.stopTest();

        //assert
        System.assertEquals(chunks, counter, 'Chunks not reached.');
   }

    
    static testmethod void testJumpServicePervertsExecution() {
        //arrange sequences
        Sequence__c origin = new Sequence__c(Name = 'Origin');
        insert origin;
        
        Sequence__c target = new Sequence__c(Name = 'Target');
        insert target;
        
        //arrange steps
        Step__c step = SequenceModel.fromId(origin.Id).appendStep(JumpService.class.getName());
        Id stepConfigId = new StepModel(step).upsertConfig();
        
        JumpStepConfig__c stepConfig = new JumpStepConfig__c(Id = stepConfigId, Sequence__c = 'Target');
        update stepConfig;
        
        //arrange input event
        Map<String,Object> inputEvent = new Map<String,Object>{
            'StepConfigId' => stepConfig.Id,
            'Route' => '1#Origin#1',
            'data' => 'herpderp'
        };
        
        //act
        ApexClassModel.Service service = new JumpService();
        List<Map<String,Object>> outputEvents = service.handle(inputEvent);
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize);
        
        String expectedToSequence = 'Target';
        String actualToSequence = (String)outputEvents[0].get('ToSequence');
        System.assertEquals(expectedToSequence, actualToSequence, 'Wrong sequence.');
        
        String expectedPassThruData = 'herpderp';
        String actualPassThruData = (String)outputEvents[0].get('data');
        System.assertEquals(expectedPassThruData, actualPassThruData);
    }
    
    static testmethod void testJumpServiceFollowsThrough() {
        //arrange sequences
        insert new Sequence__c(Name = 'Origin');
        insert new Sequence__c(Name = 'Target');
        
        //arrange steps
        Step__c originJump = SequenceModel.fromName('Origin').appendStep(JumpService.class.getName());
        Step__c originTerminate = SequenceModel.fromName('Origin').appendStep(TerminateService.class.getName());
        
        Step__c targetWiretap = SequenceModel.fromName('Target').appendStep(WiretapService.class.getName());
        Step__c targetTerminate = SequenceModel.fromName('Target').appendStep(TerminateService.class.getName());
        
        //arrange config
        Id stepConfigId = new StepModel(originJump).upsertConfig();
        update new JumpStepConfig__c(Id = stepConfigId, Sequence__c = 'Target');
        
        //act
        Test.startTest();
        Job job = new Job('Origin', '00D000000000000AAA');
        System.enqueueJob(job);
        Test.stopTest();
        
        //act
        Broker.impl().run();
        
        //assemble
        List<Message__c> messages = [SELECT Id, Name FROM Message__c WHERE Status__c = 'Completed' ALL ROWS];
        
        //assert
        Integer expectedSize = 3;
        Integer actualSize = messages.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
    }
    
}