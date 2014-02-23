@isTest //-- no view of org data
private class WiretapTest {
    
    static testMethod void testProcessIsDescribed() {
        Wiretap wiretap = new Wiretap();
        System.assertNotEquals(null, wiretap.describe().Name);
        System.assertNotEquals(null, wiretap.describe().Description);
        System.assertNotEquals(null, wiretap.describe().Tag);
    }
    
    static testMethod void callingInvokeWillNOTThrowExpectedWhenUserIdOnCustomizableNOTSet() {
        // Arrange :
        String sequenceName = 'the-sequence';
        Integer step = 1;
        String data = 'data';

       //--NOT-DEFINED insert new WiretapCustomization__c ( UserId__c = UserInfo.getUserId());

        Map<String,Object> parameters = new Map<String,Object> {
            'eda_sequenceName' => sequenceName,
            'eda_step' => step,
            'data' => data
        };
        

   

        // Act
        Wiretap wireTap = new Wiretap();
        Boolean actualFlagException = false;
        try {
            Process.PluginResult results = wireTap.invoke(new Process.PluginRequest(parameters));
        } catch (Exception e) {
           actualFlagException = true;
        }
        
 
        // Assert
        Boolean expectedFlagException = false;
        System.assertEquals(expectedFlagException , actualFlagException );
    }
   
    static testMethod void callingExecuteReturnsExpectedParametersCollectionWhenDefinedMetaCustomizableSet() {
        // Arrange :
        String sequenceName = 'the-sequence';
        Integer step = 1;
        String data = 'data';

        insert new WiretapCustomization__c ( UserId__c = UserInfo.getUserId());

        Map<String,Object> parameters = new Map<String,Object> {
            'eda_sequenceName' => sequenceName,
            'eda_step' => step,
            'data' => data
        };
        

        Integer expectedSize = 1;

        // Act
        Wiretap wireTap = new Wiretap();
        Process.PluginResult results = wireTap.invoke(new Process.PluginRequest(parameters));
        List<Map<String,Object>> actualParametersList = Utility.convert(results);

        // prepare
        Integer actualSize = actualParametersList.size();

        // Assert
        System.assertEquals(expectedSize , actualSize );
    }
}