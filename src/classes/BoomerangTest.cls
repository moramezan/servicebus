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
        
        //arrange sequences
        Sequence__c origin = new Sequence__c(Name = 'originSequence');
        insert origin;
        Step__c originStep = Steps.generateOne(origin.Id, boomerangProcess.Id);
        
        Sequence__c target = new Sequence__c(Name = 'targetSequence');
        insert target;
        Step__c targetStep = Steps.generateOne(target.Id, terminateProcess.Id);
        
        //prepare configuration in db
        BoomerangConfiguration__c config = new BoomerangConfiguration__c(
            Id = originStep.ConfigurationId__c,
            Sequence__c = target.Id
        );
        update config;
        
        //prepare message
        Process.PluginRequest request = new Process.PluginRequest(new Map<String,Object>{
            'eda__sequenceName' => 'originSequence',
            'eda__position' => 1,
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
        
        String expectedSequenceName = 'targetSequence';
        String actualSequenceName = (String)parametersList[0].get('eda__sequenceName');
        System.assertEquals(expectedSequenceName, actualSequenceName);
        
        Decimal expectedPosition = 0;
        Decimal actualPosition = (Decimal)parametersList[0].get('eda__position');
        System.assertEquals(expectedPosition, actualPosition);

        String expectedList = '["' + originStep.Id + '"]';
        String actualList = System.Json.serialize(parametersList[0].get('eda__boomerangStepIds'));
        System.assertEquals(expectedList, actualList);
    }
    
}