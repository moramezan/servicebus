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

    static testMethod void testBoomerangDropped() {
        Chain__c origin = new Chain__c(Name = 'origin');
        insert origin;
        
        Chain__c target = new Chain__c(Name = 'target');
        insert target;
        
        BranchConfiguration__c config = new BranchConfiguration__c(Chain__c = target.Id);
        insert config;
        
        Map<String,Object> parameters = new Map<String,Object>{
            'eda__configuration' => config.Id,
            'eda__boomerangStepIds' => new List<Id>{'000000000000000AAA'}
        };
        
        Branch branch = new Branch();
        List<Map<String,Object>> parametersList = Utility.convert(branch.invoke(new Process.PluginRequest(parameters)));
        
        List<Object> expectedIds = null;
        List<Object> actualIds = (List<Object>)parametersList[1].get('eda__boomerangStepIds');
        System.assertEquals(expectedIds, actualIds);
    }
    
    static testMethod void testTwoParameterSetsReturned() {
        //arrange chains
        Chain__c origin = new Chain__c(Name = 'originChain');
        Chain__c target = new Chain__c(Name = 'targetChain');
        insert origin;
        insert target;
        
        //arrange config
        BranchConfiguration__c config = new BranchConfiguration__c(Chain__c = target.Id);
        insert config;
        
        //arrange parameters
        Map<String,Object> parameters = new Map<String,Object>{
            'eda__chainName' => origin.Name,
            'eda__sequence' => 1,
            'eda__configuration' => config.Id
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
        String expectedNormalChainName = origin.Name;
        String actualNormalChainName = (String)normalParameters.get('eda__chainName');
        System.assertEquals(expectedNormalChainName, actualNormalChainName);
        
        Decimal expectedNormalSequence = 1;
        Decimal expectedActualSequence = (Decimal)normalParameters.get('eda__sequence');
        System.assertEquals(expectedNormalSequence, expectedActualSequence);
        
        //act
        Map<String,Object> branchParameters = parametersList[1]; //the branch parameters goes to the top of another chain
        
        //asserts
        String expectedBranchChainName = target.Name;
        String actualBranchChainName = (String)branchParameters.get('eda__chainName');
        System.assertEquals(expectedBranchChainName, actualBranchChainName);
        
        Decimal expectedBranchSequence = 0;
        Decimal actualBranchSequence = (Decimal)branchParameters.get('eda__sequence');
        System.assertEquals(expectedBranchSequence, actualBranchSequence);
    }
    
    static testMethod void testInfiniteLoopFuckupGetsCaught() {
        //arrange chains
        Chain__c chain = new Chain__c(Name = 'originChain');
        insert chain;
        
        //arrange config
        BranchConfiguration__c config = new BranchConfiguration__c(Chain__c = chain.Id);
        insert config;
        
        //arrange parameters
        Map<String,Object> parameters = new Map<String,Object>{
            'eda__chainName' => chain.Name,
            'eda__sequence' => 1,
            'eda__configuration' => config.Id
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