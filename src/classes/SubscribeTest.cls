@IsTest class SubscribeTest{

    static testmethod void hasTheCorrectLimits() {
        //arrange
        ApexClassModel.Summary summary = new ApexClassModel.Summary(Subscribe.class);
        
        //assert
        Integer expectedLimits = 100;
        Integer actualLimits = summary.Limits;
        System.assertEquals(expectedLimits, actualLimits);
    }

   static testmethod void withinSystemLimits() {
        //arrange
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;

        Map<String,Object> inputEvent = new Map<String,Object> {
            'Route' => 'Test#1'
        };

        //assemble
        ApexClassModel.Summary summary = new ApexClassModel.Summary(Subscribe.class);

        //act
        Test.startTest();
        Integer limits = summary.Limits;
        Integer counter = 0;
        for (Integer i = 0; i < limits; i++) {
            ApexClassModel.Service service = new Subscribe();
            List<Map<String,Object>> outputs = service.handle(inputEvent);
            counter++;
        }
        Test.stopTest();

        //assert
        System.assertEquals(limits, counter, 'Limit not reached.');
   }


    static testmethod void testSubscribeActsAsNoop() {
        //arrange
        Map<String,Object> parameters = new Map<String,Object>{'herp' => 'derp'};
            
        //act
        ApexClassModel.Service service = new Subscribe();
        List<Map<String,Object>> parametersList = service.handle(parameters);
        
        //assert
        integer expectedSize = 1;
        integer actualSize = parametersList.size();
        System.assertEquals(expectedSize , actualSize);
        
        string expectedData = 'derp';
        string actualData = (String)parametersList[0].get('herp');
        System.assertEquals(expectedData, actualData);
    }
    
}