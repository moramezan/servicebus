@IsTest class TerminateServiceTest {
    
    static testmethod void hasTheCorrectChunks() {
        //arrange
        ApexClassModel.Definition definition = new ApexClassModel.Definition(TerminateService.class);
        
        //assert
        Integer expectedChunks = 200; //max sync limit
        Integer actualChunks = definition.Chunks;
        System.assertEquals(expectedChunks, actualChunks);
    }

    static testmethod void withinSystemLimits() {
        //arrange
        Sequence__c sequence = new Sequence__c(Name = 'Terminate');
        insert sequence;
        
        Map<String,Object> inputEvent = new Map<String,Object>();
        inputEvent.put('Route', '1#Terminate#1');
        
        //assemble
        ApexClassModel.Definition definition = new ApexClassModel.Definition(TerminateService.class);
        
        //act
        Test.startTest();
        Integer chunks = definition.Chunks;
        Integer counter = 0;
        for (Integer i = 0; i < chunks; i++) {
            ApexClassModel.Service service = new TerminateService();
            List<Map<String,Object>> outputs = service.handle(inputEvent);
            counter++;
        }
        Test.stopTest();

        //assert
        System.assertEquals(chunks, counter, 'Chunks not reached.');
    }

}