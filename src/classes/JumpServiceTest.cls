@IsTest class JumpServiceTest {
     
    static testmethod void hasTheCorrectChunks() {
        //arrange
        ApexClassModel.Summary summary = new ApexClassModel.Summary(JumpService.class);
        
        //assert
        Integer expectedChunks = 50; //max sync limit
        Integer actualChunks = summary.Chunks;
        System.assertEquals(expectedChunks, actualChunks);
    }


   static testmethod void withinSystemLimits() {
        //arrange
        ApexClassModel.Summary summary = new ApexClassModel.Summary(JumpService.class);
        
        //arrange
        Sequence__c target = new Sequence__c(Name = 'Target');
        insert target;
        SequenceModel.fromName(target.Name).appendStep(TerminateService.class);
        
        JumpStepConfig__c config = new JumpStepConfig__c(Name = target.Id, Sequence__c = 'Target');
        insert config;
        
        Sequence__c origin = new Sequence__c(Name = 'Origin');
        insert origin;
        SequenceModel.fromName(origin.Name).appendStep(JumpService.class);
        SequenceModel.fromName(origin.Name).appendStep(TerminateService.class);
        
        
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
        Step__c step = SequenceModel.fromId(origin.Id).appendStep(JumpService.class);
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
    
}