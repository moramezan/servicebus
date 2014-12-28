@IsTest private class BranchTest {

    static testmethod void hasTheCorrectLimits() {
        //arrange 
        Type actualType = Branch.class;
        Type outerClass = Type.forName(actualType.getName());  
        Type innerClass = Type.forName(outerClass.getName() + '.' + 'ESB'); 
        ProcessObject.ESB meta = (ProcessObject.ESB)Json.deserialize(Json.serialize(innerClass.newInstance()), ProcessObject.ESB.class);
        
        //act 
        Integer actualLimits = meta.Limits;  

        //assemble
        actualLimits = (actualLimits == null) ? 1 : actualLimits; 

        //assert
        Integer expectedLimits = 1;
        System.assertEquals(expectedLimits, actualLimits);
    }
  
    
    static testmethod void canDetermineStepConfig() {
        //arrange processes
        Process__c branchProcess = ProcessObject.generateOne(Branch.class);
        
        //act
        String actualConfig = branchProcess.StepConfig__c;
        
        //assert
        String expectedConfig = Schema.SobjectType.BranchConfig__c.Name;
        System.assertEquals(expectedConfig, actualConfig);
    }

    static testmethod void testSubsequenceDropped() {
        Sequence__c origin = new Sequence__c(Name = 'origin');
        insert origin;
        
        Sequence__c target = new Sequence__c(Name = 'target');
        insert target;
        
        BranchConfig__c config = new BranchConfig__c(Sequence__c = target.Id);
        insert config;
        
        Map<String,Object> parameters = new Map<String,Object>{
            '__SubsequenceStepIds' => new List<Id>{'000000000000000AAA'}
        };
        
        Type reflector = Branch.class;
        List<Map<String,Object>> parametersList = new Broker.Wrapper(reflector, parameters, config).invokeMain().Outputs;

        List<Object> expectedIds = null;
        List<Object> actualIds = (List<Object>)parametersList[1].get('__SubsequenceStepIds');
        System.assertEquals(expectedIds, actualIds);
    }
    
    static testmethod void testTwoParameterSetsReturned() {
        //arrange sequences
        Sequence__c origin = new Sequence__c(Name = 'originSequence');
        Sequence__c target = new Sequence__c(Name = 'targetSequence');
        insert origin;
        insert target;
        
        //arrange config
        BranchConfig__c config = new BranchConfig__c(Sequence__c = target.Id);
        insert config;
        
        //arrange parameters
        Map<String,Object> parameters = new Map<String,Object>{
            '__SequenceName' => origin.Name,
            '__Position' => 1
        };
        
        //act
        Type reflector = Branch.class;
        List<Map<String,Object>> parametersList = new Broker.Wrapper(reflector, parameters, config).invokeMain().Outputs;

        //assert
        Decimal expectedSize = 2;
        Decimal actualSize = parametersList.size();
        System.assertEquals(expectedSize, actualSize);
        
        //act
        Map<String,Object> normalParameters = parametersList[0]; //the normal parameters continues to the next step
        
        //asserts
        String expectedNormalSequenceName = origin.Name;
        String actualNormalSequenceName = (String)normalParameters.get('__SequenceName');
        System.assertEquals(expectedNormalSequenceName, actualNormalSequenceName);
        
        Decimal expectedNormalPosition = 1;
        Decimal expectedActualPosition = (Decimal)normalParameters.get('__Position');
        System.assertEquals(expectedNormalPosition, expectedActualPosition);
        
        //act
        Map<String,Object> branchParameters = parametersList[1]; //the branch parameters goes to the top of another sequence
        
        //asserts
        String expectedBranchSequenceName = target.Name;
        String actualBranchSequenceName = (String)branchParameters.get('__SequenceName');
        System.assertEquals(expectedBranchSequenceName, actualBranchSequenceName);
        
        Decimal expectedBranchPosition = 0;
        Decimal actualBranchPosition = (Decimal)branchParameters.get('__Position');
        System.assertEquals(expectedBranchPosition, actualBranchPosition);
    }
    
    static testmethod void testInfiniteLoopFuckupGetsCaught() {
        //arrange sequences
        Sequence__c sequence = new Sequence__c(Name = 'originSequence');
        insert sequence;
        
        //arrange config
        BranchConfig__c config = new BranchConfig__c(Sequence__c = sequence.Id);
        insert config;
        
        //arrange parameters
        Map<String,Object> parameters = new Map<String,Object>{
            '__SequenceName' => sequence.Name,
            '__Position' => 1
        };
        
        //arrange exception
        Boolean exceptionThrown = false;
        
        //act
        try {
            Type reflector = Branch.class;
            List<Map<String,Object>> parametersList = new Broker.Wrapper(reflector, parameters, config).invokeMain().Outputs;
        } catch (Exception e) {
            exceptionThrown = true;
            System.assert(e instanceof Branch.BranchException);
        }
        
        //assert
        System.assert(exceptionThrown);
    }

}