@IsTest //-- no view of org data
private class WiretapTest {
    
    static testmethod void hasTheCorrectLimits() {
        //arrange
        ApexClassModel.Summary summary = new ApexClassModel.Summary(Wiretap.class);
        
        //assert
        Integer expectedLimits = 5;
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
        
        //arrange
        ApexClassModel.Summary summary = new ApexClassModel.Summary(Wiretap.class);

        //act
        Test.startTest();
        Integer limits = summary.Limits;
        Integer counter = 0;
        for (Integer i = 0; i < limits; i++) {
            ApexClassModel.Service service = new Wiretap();
            List<Map<String,Object>> outputs = service.handle(inputEvent);
            counter++;
        }
        Test.stopTest();

        //assert
        System.assertEquals(limits, counter, 'Limit not reached.');
   }




    static testmethod void callingInvokeWillNOTThrowExpectedWhenUserIdOnServiceSettingNOTSet() {
        // Arrange :
        String sequenceName = 'Test';
        Integer step = 1;
        String data = 'data';

       //--NOT-DEFINED insert new WiretapSetting__c ( UserId__c = UserInfo.getUserId());

        Map<String,Object> parameters = new Map<String,Object> {
            'Route' => 'Test#1',
            'step' => step,
            'data' => data
        };
        

   

        // Act
        Boolean actualFlagException = false;
        try {
            ApexClassModel.Service service = new Wiretap();
            List<Map<String,Object>> results = service.handle(parameters);
        } catch (Exception e) {
           actualFlagException = true;
        }
        
 
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
            'Route' => 'Test#1',
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