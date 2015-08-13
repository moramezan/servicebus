@IsTest private class BranchTest {

    static testmethod void hasTheCorrectLimits() {
        //arrange
        ApexClassModel.Summary esb = ApexClassModel.esbFromEsb(Branch.class);
        
        //assert
        Integer expectedLimits = 50; //max sync limit
        Integer actualLimits = esb.Limits;
        System.assertEquals(expectedLimits, actualLimits);
    }


   static testmethod void withinSystemLimits() {
        //arrange
        ApexClassModel.Summary esb = ApexClassModel.esbFromEsb(Branch.class);
        
        //arrange
        Sequence__c origin = new Sequence__c(Name = 'originSequence');
        Sequence__c target = new Sequence__c(Name = 'targetSequence');
        insert origin;
        insert target;
        
        //arrange config
        BranchConfig__c config = new BranchConfig__c(Sequence__c = target.Id);
        insert config;
        
        //arrange input event
        Map<String,Object> inputEvent = new Map<String,Object>{
            'esb__StepConfigId' => config.Id,
            '__SequenceName' => origin.Name,
            '__Position' => 1
        };


        //act
        Test.startTest();
        Integer limits = esb.Limits;
        Integer counter = 0;
        for (Integer i = 0; i < limits; i++) {
            ApexClassModel.BaseProcess process = new Branch();
            List<Map<String,Object>> outputs = process.test(inputEvent);
            counter++;
        }
        Test.stopTest();

        //assert
        System.assertEquals(limits, counter, 'Limit not reached.');
   }


    static testmethod void testSubsequenceDropped() {
        Sequence__c origin = new Sequence__c(Name = 'origin');
        insert origin;
        
        Sequence__c target = new Sequence__c(Name = 'target');
        insert target;
        
        BranchConfig__c config = new BranchConfig__c(Sequence__c = target.Id);
        insert config;
        
        Map<String,Object> inputEvent = new Map<String,Object>{
            'esb__StepConfigId' => config.Id,
            '__SubsequenceStepIds' => new List<Id>{'000000000000000AAA'}
        };
        
        ApexClassModel.BaseProcess process = new Branch();
        List<Map<String,Object>> outputEvents = process.test(inputEvent);

        List<Object> expectedIds = null;
        List<Object> actualIds = (List<Object>)outputEvents[1].get('__SubsequenceStepIds');
        System.assertEquals(expectedIds, actualIds);
    }
    
    static testmethod void testTwoEventsReturned() {
        //arrange sequences
        Sequence__c origin = new Sequence__c(Name = 'originSequence');
        Sequence__c target = new Sequence__c(Name = 'targetSequence');
        insert origin;
        insert target;
        
        //arrange config
        BranchConfig__c config = new BranchConfig__c(Sequence__c = target.Id);
        insert config;
        
        //arrange input event
        Map<String,Object> inputEvent = new Map<String,Object>{
            'esb__StepConfigId' => config.Id,
            '__SequenceName' => origin.Name,
            '__Position' => 1
        };
        
        //act
        ApexClassModel.BaseProcess process = new Branch();
        List<Map<String,Object>> outputEvents = process.test(inputEvent);

        //assert
        Integer expectedSize = 2;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize);
        
        //act
        Map<String,Object> normalEvent = outputEvents[0]; //the normal event continues to the next step
        
        //asserts
        String expectedNormalSequenceName = origin.Name;
        String actualNormalSequenceName = (String)normalEvent.get('__SequenceName');
        System.assertEquals(expectedNormalSequenceName, actualNormalSequenceName);
        
        Integer expectedNormalPosition = 1;
        Integer expectedActualPosition = (Integer)normalEvent.get('__Position');
        System.assertEquals(expectedNormalPosition, expectedActualPosition);
        
        //act
        Map<String,Object> branchEvent = outputEvents[1]; //the branch event goes to the top of another sequence
        
        //asserts
        String expectedBranchSequenceName = target.Name;
        String actualBranchSequenceName = (String)branchEvent.get('__SequenceName');
        System.assertEquals(expectedBranchSequenceName, actualBranchSequenceName);
        
        Integer expectedBranchPosition = 0;
        Integer actualBranchPosition = (Integer)branchEvent.get('__Position');
        System.assertEquals(expectedBranchPosition, actualBranchPosition);
    }
    
    static testmethod void testInfiniteLoopFuckupGetsCaught() {
        //arrange sequences
        Sequence__c sequence = new Sequence__c(Name = 'originSequence');
        insert sequence;
        
        //arrange config
        BranchConfig__c config = new BranchConfig__c(Sequence__c = sequence.Id);
        insert config;
        
        //arrange event
        Map<String,Object> inputEvent = new Map<String,Object>{
            'esb__StepConfigId' => config.Id,
            '__SequenceName' => sequence.Name,
            '__Position' => 1
        };
        
        //arrange exception
        Boolean exceptionThrown = false;
        
        //act
        try {
            ApexClassModel.BaseProcess process = new Branch();
            List<Map<String,Object>> outputEvents = process.test(inputEvent);
        } catch (Exception e) {
            exceptionThrown = true;
            System.assert(e instanceof Branch.BranchException);
        }
        
        //assert
        System.assert(exceptionThrown);
    }

}