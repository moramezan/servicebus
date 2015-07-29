@IsTest private class SubsequenceTest {
 
    static testmethod void hasTheCorrectLimits() {
        //assert
        Integer expectedLimits = 50;
        Integer actualLimits = new Subsequence.ESB().Limits;
        System.assertEquals(expectedLimits, actualLimits);
    }
    
    static testmethod void testMessageIsRedirected() {
        //arrange sequences
        Sequence__c origin = new Sequence__c(Name = 'originSequence');
        insert origin;
        Step__c originStep = SequenceModel.fromName(origin.Name).appendStep(Subsequence.class.getName());
        
        Sequence__c target = new Sequence__c(Name = 'targetSequence');
        insert target;
        Step__c targetStep = SequenceModel.fromName(target.Name).appendStep(Terminate.class.getName());
        
        //prepare config in db
        SubsequenceConfig__c config = new SubsequenceConfig__c(
            Id = originStep.ConfigId__c,
            Sequence__c = target.Id
        );
        update config;
        
        //prepare message
        Map<String,Object> parameters = new Map<String,Object>{
            'esb__StepConfig' => config,
            '__SequenceName' => 'originSequence',
            '__Position' => 1
        };
        
        //act
        ApexClassModel.BaseProcess process = new Subsequence();
        List<Map<String,Object>> parametersList = process.execute(parameters);
        
        //asserts
        Decimal expectedSize = 1;
        Decimal actualSize = parametersList.size();
        System.assertEquals(expectedSize, actualSize);
        
        String expectedSequenceName = 'targetSequence';
        String actualSequenceName = (String)parametersList[0].get('__SequenceName');
        System.assertEquals(expectedSequenceName, actualSequenceName);
        
        Decimal expectedPosition = 0;
        Decimal actualPosition = (Decimal)parametersList[0].get('__Position');
        System.assertEquals(expectedPosition, actualPosition);

        String expectedList = '["' + originStep.Id + '"]';
        String actualList = System.Json.serialize(parametersList[0].get('__SubsequenceStepIds'));
        System.assertEquals(expectedList, actualList);
    }
    
}