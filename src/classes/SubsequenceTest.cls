@IsTest private class SubsequenceTest {

    static testmethod void canDetermineConfigObject() {
        //arrange processes
        Process__c subsequenceProcess = ProcessObject.generateOne(Subsequence.class);
        
        //act
        String actualConfiguration = subsequenceProcess.ConfigObject__c;
        
        //assert
        String expectedConfiguration = Schema.SobjectType.SubsequenceConfiguration__c.Name;
        System.assertEquals(expectedConfiguration, actualConfiguration);
    }

    static testmethod void testMessageIsRedirected() {
        //arrange processes
        Process__c subsequenceProcess = ProcessObject.generateOne(Subsequence.class);
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        
        //arrange sequences
        Sequence__c origin = new Sequence__c(Name = 'originSequence');
        insert origin;
        Step__c originStep = StepObject.generateOne(origin.Id, subsequenceProcess.Id);
        
        Sequence__c target = new Sequence__c(Name = 'targetSequence');
        insert target;
        Step__c targetStep = StepObject.generateOne(target.Id, terminateProcess.Id);
        
        //prepare configuration in db
        SubsequenceConfiguration__c config = new SubsequenceConfiguration__c(
            Id = originStep.ConfigurationId__c,
            Sequence__c = target.Id
        );
        update config;
        
        //prepare message
        Map<String,Object> parameters = new Map<String,Object>{
            'eda_SequenceName' => 'originSequence',
            'eda_Position' => 1,
            'eda_ConfigObjectId' => config.Id
        };
        
        //act
        Type reflector = Subsequence.class;
        List<Map<String,Object>> parametersList = new Broker.Wrapper(reflector, parameters).invokeMain().Outputs;
        
        //asserts
        Decimal expectedSize = 1;
        Decimal actualSize = parametersList.size();
        System.assertEquals(expectedSize, actualSize);
        
        String expectedSequenceName = 'targetSequence';
        String actualSequenceName = (String)parametersList[0].get('eda_SequenceName');
        System.assertEquals(expectedSequenceName, actualSequenceName);
        
        Decimal expectedPosition = 0;
        Decimal actualPosition = (Decimal)parametersList[0].get('eda_Position');
        System.assertEquals(expectedPosition, actualPosition);

        String expectedList = '["' + originStep.Id + '"]';
        String actualList = System.Json.serialize(parametersList[0].get('eda_SubsequenceStepIds'));
        System.assertEquals(expectedList, actualList);
    }
    
}