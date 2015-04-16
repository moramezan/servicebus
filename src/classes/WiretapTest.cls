@IsTest //-- no view of org data
private class WiretapTest {
    
    static testmethod void hasTheCorrectLimits() {
        //assert
        Integer expectedLimits = 5;
        Integer actualLimits = new Wiretap.ESB().Limits;
        System.assertEquals(expectedLimits, actualLimits);
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
            ProcessModel.BaseProcess process = new Wiretap();
            List<Map<String,Object>> results = process.execute(parameters);
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
        ProcessModel.BaseProcess process = new Wiretap();
        List<Map<String,Object>> actualParametersList = process.execute(inputEvent);

        // prepare
        Integer actualSize = actualParametersList.size();

        // Assert
        System.assertEquals(expectedSize , actualSize );
    }
}