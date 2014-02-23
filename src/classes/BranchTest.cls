@isTest private class BranchTest {

    static testMethod void canDetermineConfigurable() {
        //arrange processes
        Process__c branchProcess = Processes.generateOne(Branch.class);
        
        //act
        String actualConfiguration = branchProcess.Configurable__c;
        
        //assert
        String expectedConfiguration = Schema.SobjectType.BranchConfiguration__c.Name;
        System.assertEquals(expectedConfiguration, actualConfiguration);
    }

    static testMethod void testSubsequenceDropped() {
        Sequence__c origin = new Sequence__c(Name = 'origin');
        insert origin;
        
        Sequence__c target = new Sequence__c(Name = 'target');
        insert target;
        
        BranchConfiguration__c config = new BranchConfiguration__c(Sequence__c = target.Id);
        insert config;
        
        Map<String,Object> parameters = new Map<String,Object>{
            'eda_configuration' => config.Id,
            'eda_subsequenceStepIds' => new List<Id>{'000000000000000AAA'}
        };
        
        Branch branch = new Branch();
        List<Map<String,Object>> parametersList = Utility.convert(branch.invoke(new Process.PluginRequest(parameters)));
        
        List<Object> expectedIds = null;
        List<Object> actualIds = (List<Object>)parametersList[1].get('eda_subsequenceStepIds');
        System.assertEquals(expectedIds, actualIds);
    }
    
    static testMethod void testTwoParameterSetsReturned() {
        //arrange sequences
        Sequence__c origin = new Sequence__c(Name = 'originSequence');
        Sequence__c target = new Sequence__c(Name = 'targetSequence');
        insert origin;
        insert target;
        
        //arrange config
        BranchConfiguration__c config = new BranchConfiguration__c(Sequence__c = target.Id);
        insert config;
        
        //arrange parameters
        Map<String,Object> parameters = new Map<String,Object>{
            'eda_sequenceName' => origin.Name,
            'eda_position' => 1,
            'eda_configuration' => config.Id
        };
        
        //arrange processable
        Branch process = new Branch();
        
        //act
        Process.PluginResult result = process.invoke(new Process.PluginRequest(parameters));
        List<Map<String,Object>> parametersList = Utility.convert(result);
        
        //assert
        Decimal expectedSize = 2;
        Decimal actualSize = parametersList.size();
        System.assertEquals(expectedSize, actualSize);
        
        //act
        Map<String,Object> normalParameters = parametersList[0]; //the normal parameters continues to the next step
        
        //asserts
        String expectedNormalSequenceName = origin.Name;
        String actualNormalSequenceName = (String)normalParameters.get('eda_sequenceName');
        System.assertEquals(expectedNormalSequenceName, actualNormalSequenceName);
        
        Decimal expectedNormalPosition = 1;
        Decimal expectedActualPosition = (Decimal)normalParameters.get('eda_position');
        System.assertEquals(expectedNormalPosition, expectedActualPosition);
        
        //act
        Map<String,Object> branchParameters = parametersList[1]; //the branch parameters goes to the top of another sequence
        
        //asserts
        String expectedBranchSequenceName = target.Name;
        String actualBranchSequenceName = (String)branchParameters.get('eda_sequenceName');
        System.assertEquals(expectedBranchSequenceName, actualBranchSequenceName);
        
        Decimal expectedBranchPosition = 0;
        Decimal actualBranchPosition = (Decimal)branchParameters.get('eda_position');
        System.assertEquals(expectedBranchPosition, actualBranchPosition);
    }
    
    static testMethod void testInfiniteLoopFuckupGetsCaught() {
        //arrange sequences
        Sequence__c sequence = new Sequence__c(Name = 'originSequence');
        insert sequence;
        
        //arrange config
        BranchConfiguration__c config = new BranchConfiguration__c(Sequence__c = sequence.Id);
        insert config;
        
        //arrange parameters
        Map<String,Object> parameters = new Map<String,Object>{
            'eda_sequenceName' => sequence.Name,
            'eda_position' => 1,
            'eda_configuration' => config.Id
        };
        
        //arrange process
        Branch process = new Branch();
        
        //arrange exception
        Boolean exceptionThrown = false;
        
        //act
        try {
            Process.PluginResult result = process.invoke(new Process.PluginRequest(parameters));
            List<Map<String,Object>> parametersList = Utility.convert(result);
        } catch (Exception e) {
            exceptionThrown = true;
            System.assert(e instanceof Branch.BranchException);
        }
        
        //assert
        System.assert(exceptionThrown);
    }

}