@IsTest class BranchServiceTest {

    static testmethod void hasTheCorrectChunks() {
        //arrange
        ApexClassModel.Summary summary = new ApexClassModel.Summary(BranchService.class);
        
        //assert
        Integer expectedChunks = 50; //max sync limit
        Integer actualChunks = summary.Chunks;
        System.assertEquals(expectedChunks, actualChunks);
    }


   static testmethod void withinSystemLimits() {
        //arrange chunks
        ApexClassModel.Summary summary = new ApexClassModel.Summary(BranchService.class);
        
        //arrange sequences
        Sequence__c origin = new Sequence__c(Name = 'Origin');
        insert origin;
        
        Sequence__c target = new Sequence__c(Name = 'Target');
        insert target;
        
        //arrange steps
        Step__c step = SequenceModel.fromId(origin.Id).appendStep(BranchService.class);
        Id stepConfigId = new StepModel(step).upsertConfig();
        
        BranchStepConfig__c stepConfig = new BranchStepConfig__c(Id = stepConfigId, Sequence__c = 'Target');
        update stepConfig;
        
        //arrange input event
        Map<String,Object> inputEvent = new Map<String,Object>{
            'StepConfigId' => stepConfigId,
            'Route' => '1#Origin#1'
        };


        //act
        Test.startTest();
        Integer chunks = summary.Chunks;
        Integer counter = 0;
        for (Integer i = 0; i < chunks; i++) {
            ApexClassModel.Service service = new BranchService();
            List<Map<String,Object>> outputs = service.handle(inputEvent);
            counter++;
        }
        Test.stopTest();

        //assert
        System.assertEquals(chunks, counter, 'Chunks not reached.');
   }

    static testmethod void testTwoEventsReturned() {
        //arrange sequences
        Sequence__c origin = new Sequence__c(Name = 'Origin');
        insert origin;
        
        Sequence__c target = new Sequence__c(Name = 'Target');
        insert target;
        
        //arrange steps
        Step__c step = SequenceModel.fromId(origin.Id).appendStep(BranchService.class);
        Id stepConfigId = new StepModel(step).upsertConfig();
        
        BranchStepConfig__c stepConfig = new BranchStepConfig__c(Id = stepConfigId, Sequence__c = 'Target');
        update stepConfig;
        
        //arrange input event
        Map<String,Object> inputEvent = new Map<String,Object>{
            'StepConfigId' => stepConfigId,
            'Route' => '1#Origin#1'
        };
        
        //act
        ApexClassModel.Service service = new BranchService();
        List<Map<String,Object>> outputEvents = service.handle(inputEvent);

        //assert
        Integer expectedSize = 2;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize);
        
        //arrange
        Map<String,Object> normalEvent = outputEvents[0]; //the normal event continues to the next step
        
        //asserts
        String expectedRoute = '1#Origin#1';
        String actualRoute = (String)normalEvent.get('Route');
        System.assertEquals(expectedRoute, actualRoute, 'Wrong normal route.');
        
        //arrange
        Map<String,Object> branchEvent = outputEvents[1]; //the branch event goes to the top of another sequence
        
        //asserts
        String expectedSequence = '1' + '#' + target.Name + '#' + '0';
        String actualSequence = (String)branchEvent.get('Route');
        System.assertEquals(expectedSequence, actualSequence, 'Wrong branch sequence.');
    }
    
    static testmethod void testInfiniteLoopFuckupGetsCaught() {
        //arrange sequences
        Sequence__c sequence = new Sequence__c(Name = 'Origin');
        insert sequence;
        
        //arrange config
        BranchStepConfig__c config = new BranchStepConfig__c(Name = sequence.Id, Sequence__c = 'Origin');
        insert config;
        
        //arrange event
        Map<String,Object> inputEvent = new Map<String,Object>{
            'StepConfigId' => config.Id,
            'Route' => '1#Origin#1'
        };
        
        //arrange exception
        Boolean exceptionThrown = false;
        
        //act
        try {
            ApexClassModel.Service service = new BranchService();
            List<Map<String,Object>> outputEvents = service.handle(inputEvent);
        } catch (BranchService.ServiceException e) {
            exceptionThrown = true;
        }
        
        //assert
        System.assert(exceptionThrown);
    }

}