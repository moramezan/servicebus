@isTest private class BoomerangTest {

    static testMethod void canDetermineConfigurable() {
        //arrange processes
        Process__c boomerangProcess = Processes.generateOne(Boomerang.class);
        
        //act
        String actualConfiguration = boomerangProcess.Configurable__c;
        
        //assert
        String expectedConfiguration = Schema.SobjectType.BoomerangConfiguration__c.Name;
        System.assertEquals(expectedConfiguration, actualConfiguration);
    }

    static testMethod void testMessageIsRedirected() {
        //arrange processes
        Process__c boomerangProcess = Processes.generateOne(Boomerang.class);
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        
        //arrange chains
        Chain__c origin = new Chain__c(Name = 'originChain');
        insert origin;
        ChainStep__c originChainStep = ChainSteps.generateOne(origin.Id, boomerangProcess.Id);
        
        Chain__c target = new Chain__c(Name = 'targetChain');
        insert target;
        ChainStep__c targetChainStep = ChainSteps.generateOne(target.Id, terminateProcess.Id);
        
        //prepare configuration in db
        BoomerangConfiguration__c config = new BoomerangConfiguration__c(
            Id = originChainStep.ConfigurationId__c,
            Chain__c = target.Id
        );
        update config;
        
        //prepare message
        Process.PluginRequest request = new Process.PluginRequest(new Map<String,Object>{
            'eda__chainName' => 'originChain',
            'eda__sequence' => 1,
            'eda__configuration' => config.Id
        });
        
        //act
        Boomerang process = new Boomerang();
        Process.PluginResult result = process.invoke(request);
        List<Map<String,Object>> parametersList = Utility.convert(result);
        
        //asserts
        Decimal expectedSize = 1;
        Decimal actualSize = parametersList.size();
        System.assertEquals(expectedSize, actualSize);
        
        String expectedChainName = 'targetChain';
        String actualChainName = (String)parametersList[0].get('eda__chainName');
        System.assertEquals(expectedChainName, actualChainName);
        
        Decimal expectedSequence = 0;
        Decimal actualSequence = (Decimal)parametersList[0].get('eda__sequence');
        System.assertEquals(expectedSequence, actualSequence);

        String expectedList = '["' + originChainStep.Id + '"]';
        String actualList = System.Json.serialize(parametersList[0].get('eda__boomerangChainStepIds'));
        System.assertEquals(expectedList, actualList);
    }
    
}