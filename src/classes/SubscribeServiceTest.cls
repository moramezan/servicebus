@IsTest class SubscribeServiceTest{

    static testmethod void hasTheCorrectChunks() {
        //arrange
        ApexClassModel.Definition definition = new ApexClassModel.Definition(SubscribeService.class);
        
        //assert
        Integer expectedChunks = 100;
        Integer actualChunks = definition.Chunks;
        System.assertEquals(expectedChunks, actualChunks);
    }

   static testmethod void withinSystemChunks() {
        //arrange
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;

        Map<String,Object> inputEvent = new Map<String,Object> {
            'Route' => '1#Test#1'
        };

        //assemble
        ApexClassModel.Definition definition = new ApexClassModel.Definition(SubscribeService.class);

        //act
        Test.startTest();
        Integer chunks = definition.Chunks;
        Integer counter = 0;
        for (Integer i = 0; i < chunks; i++) {
            ApexClassModel.Service service = new SubscribeService();
            List<Map<String,Object>> outputs = service.handle(inputEvent);
            counter++;
        }
        Test.stopTest();

        //assert
        System.assertEquals(chunks, counter, 'Chunks not reached.');
   }


    static testmethod void testSubscribeActsAsNoop() {
        //arrange
        Map<String,Object> parameters = new Map<String,Object>{'herp' => 'derp'};
            
        //act
        ApexClassModel.Service service = new SubscribeService();
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