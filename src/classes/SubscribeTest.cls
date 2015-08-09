@IsTest private class SubscribeTest{

    static testmethod void hasTheCorrectLimits() {
        //assert
        Integer expectedLimits = 5000;
        Integer actualLimits = new Subscribe.ESB().Limits;
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


        //act
        Test.startTest();
        Integer limits = new Subscribe.Esb().Limits;
        Integer counter = 0;
        for (Integer i = 0; i < limits; i++) {
            ApexClassModel.BaseProcess process = new Subscribe();
            List<Map<String,Object>> outputs = process.execute(inputEvent);
            counter++;
        }
        Test.stopTest();

        //assert
        System.assertEquals(limits, counter, 'Limit not reached.');
   }


    static testmethod void testSubscribeProcessActsAsNoop() {
        //arrange
        String data = '{"herp":"derp"}';
        Map<String,Object> parameters = (Map<String,Object>)System.Json.deserializeUntyped(data);
        
        //act
        ApexClassModel.BaseProcess process = new Subscribe();
        List<Map<String,Object>> parametersList = process.execute(parameters);
        
        //assert
        integer expectedSize = 1;
        integer actualSize = parametersList.size();
        System.assertEquals(expectedSize , actualSize);
        
        string expectedData = data;
        string actualData = system.json.serialize(parametersList[0]);
        System.assertEquals(expectedData, actualData);
    }
    
}