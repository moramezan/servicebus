@IsTest private class BranchTest {

    static testmethod void hasTheCorrectLimits() {
        //arrange
        ApexClassModel.Summary summary = new ApexClassModel.Summary(Branch.class);
        
        //assert
        Integer expectedLimits = 50; //max sync limit
        Integer actualLimits = summary.Limits;
        System.assertEquals(expectedLimits, actualLimits);
    }


   static testmethod void withinSystemLimits() {
        //arrange limits
        ApexClassModel.Summary summary = new ApexClassModel.Summary(Branch.class);
        
        //arrange sequences
        Sequence__c origin = new Sequence__c(Name = 'Origin');
        insert origin;
        
        Sequence__c target = new Sequence__c(Name = 'Target');
        insert target;
        
        //arrange steps
        Step__c step = SequenceModel.fromId(origin.Id).appendStep(Branch.class);
        Id stepConfigId = new StepModel(step).upsertConfig();
        
        BranchConfig__c stepConfig = new BranchConfig__c(Id = stepConfigId, Sequence__c = target.Id);
        update stepConfig;
        
        //arrange input event
        Map<String,Object> inputEvent = new Map<String,Object>{
            'StepConfigId' => stepConfigId,
            'Route' => 'Origin#1'
        };


        //act
        Test.startTest();
        Integer limits = summary.Limits;
        Integer counter = 0;
        for (Integer i = 0; i < limits; i++) {
            ApexClassModel.Service service = new Branch();
            List<Map<String,Object>> outputs = service.test(inputEvent);
            counter++;
        }
        Test.stopTest();

        //assert
        System.assertEquals(limits, counter, 'Limit not reached.');
   }

    static testmethod void testTwoEventsReturned() {
        //arrange sequences
        Sequence__c origin = new Sequence__c(Name = 'Origin');
        insert origin;
        
        Sequence__c target = new Sequence__c(Name = 'Target');
        insert target;
        
        //arrange steps
        Step__c step = SequenceModel.fromId(origin.Id).appendStep(Branch.class);
        Id stepConfigId = new StepModel(step).upsertConfig();
        
        BranchConfig__c stepConfig = new BranchConfig__c(Id = stepConfigId, Sequence__c = target.Id);
        update stepConfig;
        
        //arrange input event
        Map<String,Object> inputEvent = new Map<String,Object>{
            'StepConfigId' => stepConfigId,
            'Route' => 'Origin#1'
        };
        
        //act
        ApexClassModel.Service service = new Branch();
        List<Map<String,Object>> outputEvents = service.test(inputEvent);

        //assert
        Integer expectedSize = 2;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize);
        
        //arrange
        Map<String,Object> normalEvent = outputEvents[0]; //the normal event continues to the next step
        
        //asserts
        String expectedRoute = 'Origin#1';
        String actualRoute = (String)normalEvent.get('Route');
        System.assertEquals(expectedRoute, actualRoute, 'Wrong normal route.');
        
        //arrange
        Map<String,Object> branchEvent = outputEvents[1]; //the branch event goes to the top of another sequence
        
        //asserts
        String expectedSequence = target.Name + '#0';
        String actualSequence = (String)branchEvent.get('Route');
        System.assertEquals(expectedSequence, actualSequence, 'Wrong branch sequence.');
    }
    
    static testmethod void testInfiniteLoopFuckupGetsCaught() {
        //arrange sequences
        Sequence__c sequence = new Sequence__c(Name = 'Origin');
        insert sequence;
        
        //arrange config
        BranchConfig__c config = new BranchConfig__c(Sequence__c = sequence.Id);
        insert config;
        
        //arrange event
        Map<String,Object> inputEvent = new Map<String,Object>{
            'StepConfigId' => config.Id,
            'Route' => 'Origin#1'
        };
        
        //arrange exception
        Boolean exceptionThrown = false;
        
        //act
        try {
            ApexClassModel.Service service = new Branch();
            List<Map<String,Object>> outputEvents = service.test(inputEvent);
        } catch (Exception e) {
            exceptionThrown = true;
            System.assert(e instanceof Branch.BranchException);
        }
        
        //assert
        System.assert(exceptionThrown);
    }

}