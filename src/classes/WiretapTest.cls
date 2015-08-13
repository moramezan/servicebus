@IsTest //-- no view of org data
private class WiretapTest {
    
    static testmethod void hasTheCorrectLimits() {
        //arrange
        ApexClassModel.Summary esb = ApexClassModel.esbFromEsb(Wiretap.class);
        
        //assert
        Integer expectedLimits = 5;
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
        
        //arrange
        ApexClassModel.Summary esb = ApexClassModel.esbFromEsb(Wiretap.class);

        //act
        Test.startTest();
        Integer limits = esb.Limits;
        Integer counter = 0;
        for (Integer i = 0; i < limits; i++) {
            ApexClassModel.BaseProcess process = new Wiretap();
            List<Map<String,Object>> outputs = process.test(inputEvent);
            counter++;
        }
        Test.stopTest();

        //assert
        System.assertEquals(limits, counter, 'Limit not reached.');
   }




    static testmethod void callingInvokeWillNOTThrowExpectedWhenUserIdOnProcessSettingNOTSet() {
        // Arrange :
        String sequenceName = 'the-sequence';
        Integer step = 1;
        String data = 'data';

       //--NOT-DEFINED insert new WiretapSetting__c ( UserId__c = UserInfo.getUserId());

        Map<String,Object> parameters = new Map<String,Object> {
            '__SequenceName' => sequenceName,
            'step' => step,
            'data' => data
        };
        

   

        // Act
        Boolean actualFlagException = false;
        try {
            ApexClassModel.BaseProcess process = new Wiretap();
            List<Map<String,Object>> results = process.test(parameters);
        } catch (Exception e) {
           actualFlagException = true;
        }
        
 
        // Assert
        Boolean expectedFlagException = false;
        System.assertEquals(expectedFlagException , actualFlagException );
    }
   
    static testmethod void callingExecuteReturnsExpectedOutputEventsWhenDefinedESBProcessSettingSet() {
        // Arrange :
        String sequenceName = 'the-sequence';
        Integer step = 1;
        String data = 'data';

        insert new WiretapSetting__c ( UserId__c = UserInfo.getUserId());

        Map<String,Object> inputEvent = new Map<String,Object> {
            '__SequenceName' => sequenceName,
            'step' => step,
            'data' => data
        };
        

        Integer expectedSize = 1;

        // Act
        ApexClassModel.BaseProcess process = new Wiretap();
        List<Map<String,Object>> actualParametersList = process.test(inputEvent);

        // prepare
        Integer actualSize = actualParametersList.size();

        // Assert
        System.assertEquals(expectedSize , actualSize );
    }
}