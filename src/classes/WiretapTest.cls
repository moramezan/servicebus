@IsTest class WiretapTest {
    
    static testmethod void hasTheCorrectChunks() {
        //arrange
        ApexClassModel.Summary summary = new ApexClassModel.Summary(Wiretap.class);
        
        //assert
        Integer expectedChunks = 5;
        Integer actualChunks = summary.Chunks;
        System.assertEquals(expectedChunks, actualChunks);
    }


   static testmethod void withinSystemLimits() {
        //arrange
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;

        Map<String,Object> inputEvent = new Map<String,Object> {
            'Route' => '1#Test#1'
        };
        
        //arrange
        ApexClassModel.Summary summary = new ApexClassModel.Summary(Wiretap.class);

        //act
        Test.startTest();
        Integer chunks = summary.Chunks;
        Integer counter = 0;
        for (Integer i = 0; i < chunks; i++) {
            ApexClassModel.Service service = new Wiretap();
            List<Map<String,Object>> outputs = service.handle(inputEvent);
            counter++;
        }
        Test.stopTest();

        //assert
        System.assertEquals(chunks, counter, 'Chunks not reached.');
   }




    static testmethod void callingInvokeWillNOTThrowExpectedWhenUserIdOnServiceSettingNOTSet() {
        // Arrange :
        String sequenceName = 'Test';
        Integer step = 1;
        String data = 'data';

       //--NOT-DEFINED insert new WiretapSetting__c ( UserId__c = UserInfo.getUserId());

        Map<String,Object> parameters = new Map<String,Object> {
            'Route' => '1#Test#1',
            'step' => step,
            'data' => data
        };
        

   

        // Act
        Boolean actualFlagException = false;
        ApexClassModel.Service service = new Wiretap();
        List<Map<String,Object>> results = service.handle(parameters);
 
        // Assert
        Boolean expectedFlagException = false;
        System.assertEquals(expectedFlagException , actualFlagException );
    }
   
    static testmethod void callingExecuteReturnsExpectedOutputEventsWhenDefinedServiceSettingSet() {
        // Arrange :
        String sequenceName = 'Test';
        Integer step = 1;
        String data = 'data';

        insert new WiretapSetting__c ( UserId__c = UserInfo.getUserId());

        Map<String,Object> inputEvent = new Map<String,Object> {
            'Route' => '1#Test#1',
            'step' => step,
            'data' => data
        };
        

        Integer expectedSize = 1;

        // Act
        ApexClassModel.Service service = new Wiretap();
        List<Map<String,Object>> actualParametersList = service.handle(inputEvent);

        // prepare
        Integer actualSize = actualParametersList.size();

        // Assert
        System.assertEquals(expectedSize , actualSize );
    }
}