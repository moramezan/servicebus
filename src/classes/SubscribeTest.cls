@IsTest private class SubscribeTest{

    static testmethod void hasTheCorrectLimits() {
        //arrange
        ApexClassModel.Summary esb = ApexClassModel.esbFromEsb(Subscribe.class);
        
        //assert
        Integer expectedLimits = 100;
        Integer actualLimits = esb.Limits;
        System.assertEquals(expectedLimits, actualLimits);
    }

   static testmethod void withinSystemLimits() {
        //arrange
        Sequence__c sequence = new Sequence__c(Name = 'the-sequence');
        insert sequence;

        Map<String,Object> inputEvent = new Map<String,Object> {
            '__SequenceName' => 'the-sequence',
            '__Position' => 1
        };

        //assemble
        ApexClassModel.Summary esb = ApexClassModel.esbFromEsb(Subscribe.class);

        //act
        Test.startTest();
        Integer limits = esb.Limits;
        Integer counter = 0;
        for (Integer i = 0; i < limits; i++) {
            ApexClassModel.BaseProcess process = new Subscribe();
            List<Map<String,Object>> outputs = process.test(inputEvent);
            counter++;
        }
        Test.stopTest();

        //assert
        System.assertEquals(limits, counter, 'Limit not reached.');
   }


    static testmethod void testSubscribeProcessActsAsNoop() {
        //arrange
        Map<String,Object> parameters = new Map<String,Object>{'herp' => 'derp'};
            
        //act
        ApexClassModel.BaseProcess process = new Subscribe();
        List<Map<String,Object>> parametersList = process.test(parameters);
        
        //assert
        integer expectedSize = 1;
        integer actualSize = parametersList.size();
        System.assertEquals(expectedSize , actualSize);
        
        string expectedData = 'derp';
        string actualData = (String)parametersList[0].get('herp');
        System.assertEquals(expectedData, actualData);
    }
    
}