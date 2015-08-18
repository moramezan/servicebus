@IsTest private class SubsequenceTest {
 
    static testmethod void hasTheCorrectLimits() {
        //arrange
        ApexClassModel.Summary summary = new ApexClassModel.Summary(Subsequence.class);
        
        //assert
        Integer expectedLimits = 33; //max sync limit
        Integer actualLimits = summary.Limits;
        System.assertEquals(expectedLimits, actualLimits);
    }


   static testmethod void withinSystemLimits() {
        Sequence__c origin = new Sequence__c(Name = 'Origin');
        insert origin;
        Step__c originStep = SequenceModel.fromName(origin.Name).appendStep(Subsequence.class);
        new StepModel(originStep).upsertConfig();
        
        Sequence__c target = new Sequence__c(Name = 'Target');
        insert target;
        Step__c targetStep = SequenceModel.fromName(target.Name).appendStep(Terminate.class);
        
        //prepare config in db
        SubsequenceConfig__c config = new SubsequenceConfig__c(
            Id = originStep.ConfigId__c,
            Sequence__c = target.Id
        );
        update config;
        
        //assemble
        ApexClassModel.Summary summary = new ApexClassModel.Summary(Subsequence.class);
        
        //act
        Test.startTest();
        Integer limits = summary.Limits;
        Integer counter = 0;
        for (Integer i = 0; i < limits; i++) {
            //by reference side effects on inputEvent
            //inside subsequence process logic, so new input event for each iteration!
            Map<String,Object> inputEvent = new Map<String,Object>{
                'StepConfigId' => config.Id,
                'Route' => 'Origin#1'
            };
                
            ApexClassModel.BaseProcess process = new Subsequence();
            List<Map<String,Object>> outputs = process.test(inputEvent);
            counter++;
        }
        Test.stopTest();

        //assert
        System.assertEquals(limits, counter, 'Limit not reached.');
   }



    static testmethod void testMessageIsRedirected() {
        //arrange sequences
        Sequence__c origin = new Sequence__c(Name = 'Origin');
        insert origin;
        Step__c originStep = SequenceModel.fromName(origin.Name).appendStep(Subsequence.class);
        new StepModel(originStep).upsertConfig();
        
        Sequence__c target = new Sequence__c(Name = 'Target');
        insert target;
        Step__c targetStep = SequenceModel.fromName(target.Name).appendStep(Terminate.class);
        
        //prepare config in db
        SubsequenceConfig__c config = new SubsequenceConfig__c(
            Id = originStep.ConfigId__c,
            Sequence__c = target.Id
        );
        update config;
        
        //prepare message
        Map<String,Object> parameters = new Map<String,Object>{
            'StepConfigId' => config.Id,
            'Route' => 'Origin#1'
        };
        
        //act
        ApexClassModel.BaseProcess process = new Subsequence();
        List<Map<String,Object>> parametersList = process.test(parameters);
        
        //asserts
        Integer expectedSize = 1;
        Integer actualSize = parametersList.size();
        System.assertEquals(expectedSize, actualSize);
        
        String expectedSequence = 'Target';
        String actualSequence = (String)parametersList[0].get('Sequence');
        System.assertEquals(expectedSequence, actualSequence, 'Wrong sequence.');
        
        String expectedList = '["Origin#1"]';
        String actualList = System.Json.serialize(parametersList[0].get('__SubsequenceRoutes'));
        System.assertEquals(expectedList, actualList);
    }
    
}