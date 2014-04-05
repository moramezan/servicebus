@isTest private class BranchTest {

    static testMethod void canDetermineConfigObject() {
        //arrange processes
        Process__c branchProcess = ProcessSet.generateOne(Branch.class);
        
        //act
        String actualConfiguration = branchProcess.ConfigObject__c;
        
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
            'eda_ConfigObjectId' => config.Id,
            'eda_SubsequenceStepIds' => new List<Id>{'000000000000000AAA'}
        };
        
        Branch plugin = new Branch();
        List<Map<String,Object>> parametersList = EdaUtility.convert(plugin.invoke(new Process.PluginRequest(parameters)));
        
        List<Object> expectedIds = null;
        List<Object> actualIds = (List<Object>)parametersList[1].get('eda_SubsequenceStepIds');
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
            'eda_SequenceName' => origin.Name,
            'eda_Position' => 1,
            'eda_ConfigObjectId' => config.Id
        };
        
        //arrange processable
        Branch plugin = new Branch();
        
        //act
        Process.PluginResult result = plugin.invoke(new Process.PluginRequest(parameters));
        List<Map<String,Object>> parametersList = EdaUtility.convert(result);
        
        //assert
        Decimal expectedSize = 2;
        Decimal actualSize = parametersList.size();
        System.assertEquals(expectedSize, actualSize);
        
        //act
        Map<String,Object> normalParameters = parametersList[0]; //the normal parameters continues to the next step
        
        //asserts
        String expectedNormalSequenceName = origin.Name;
        String actualNormalSequenceName = (String)normalParameters.get('eda_SequenceName');
        System.assertEquals(expectedNormalSequenceName, actualNormalSequenceName);
        
        Decimal expectedNormalPosition = 1;
        Decimal expectedActualPosition = (Decimal)normalParameters.get('eda_Position');
        System.assertEquals(expectedNormalPosition, expectedActualPosition);
        
        //act
        Map<String,Object> branchParameters = parametersList[1]; //the branch parameters goes to the top of another sequence
        
        //asserts
        String expectedBranchSequenceName = target.Name;
        String actualBranchSequenceName = (String)branchParameters.get('eda_SequenceName');
        System.assertEquals(expectedBranchSequenceName, actualBranchSequenceName);
        
        Decimal expectedBranchPosition = 0;
        Decimal actualBranchPosition = (Decimal)branchParameters.get('eda_Position');
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
            'eda_SequenceName' => sequence.Name,
            'eda_Position' => 1,
            'eda_ConfigObjectId' => config.Id
        };
        
        //arrange process
        Branch plugin = new Branch();
        
        //arrange exception
        Boolean exceptionThrown = false;
        
        //act
        try {
            Process.PluginResult result = plugin.invoke(new Process.PluginRequest(parameters));
            List<Map<String,Object>> parametersList = EdaUtility.convert(result);
        } catch (Exception e) {
            exceptionThrown = true;
            System.assert(e instanceof Branch.BranchException);
        }
        
        //assert
        System.assert(exceptionThrown);
    }

}