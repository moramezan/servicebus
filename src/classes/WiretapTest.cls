@IsTest //-- no view of org data
private class WiretapTest {
    
    static testmethod void callingInvokeWillNOTThrowExpectedWhenUserIdOnCustomSettingNOTSet() {
        // Arrange :
        String sequenceName = 'the-sequence';
        Integer step = 1;
        String data = 'data';

       //--NOT-DEFINED insert new WiretapSettings__c ( UserId__c = UserInfo.getUserId());

        Map<String,Object> parameters = new Map<String,Object> {
            'eda_SequenceName' => sequenceName,
            'eda_Step' => step,
            'data' => data
        };
        

   

        // Act
        Boolean actualFlagException = false;
        try {
            List<Map<String,Object>> results = Broker.invoke(Wiretap.class, parameters);
        } catch (Exception e) {
           actualFlagException = true;
        }
        
 
        // Assert
        Boolean expectedFlagException = false;
        System.assertEquals(expectedFlagException , actualFlagException );
    }
   
    static testmethod void callingExecuteReturnsExpectedParametersCollectionWhenDefinedMetaCustomSettingSet() {
        // Arrange :
        String sequenceName = 'the-sequence';
        Integer step = 1;
        String data = 'data';

        insert new WiretapSettings__c ( UserId__c = UserInfo.getUserId());

        Map<String,Object> parameters = new Map<String,Object> {
            'eda_SequenceName' => sequenceName,
            'eda_Step' => step,
            'data' => data
        };
        

        Integer expectedSize = 1;

        // Act
        List<Map<String,Object>> actualParametersList = Broker.invoke(Wiretap.class, parameters);

        // prepare
        Integer actualSize = actualParametersList.size();

        // Assert
        System.assertEquals(expectedSize , actualSize );
    }
}