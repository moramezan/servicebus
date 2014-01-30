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
        String chainName = 'the-chain';
        Integer chainStep = 1;
        String data = 'data';

       //--NOT-DEFINED insert new WiretapCustomization__c ( UserId__c = UserInfo.getUserId());

        Map<String,Object> notification = new Map<String,Object> {
            'eda__chainName' => chainName,
            'eda__chainStep' => chainStep,
            'data' => data
        };
        

   

        // Act
        Wiretap wireTap = new Wiretap();
        Boolean actualFlagException = false;
        try {
            Process.PluginResult results = wireTap.invoke(new Process.PluginRequest(notification)); 
        } catch (Exception e) {
           actualFlagException = true;
        }
        
 
        // Assert
        Boolean expectedFlagException = false;
        System.assertEquals(expectedFlagException , actualFlagException );
    }  
   
    static testMethod void callingExecuteReturnsExpectedNotificationCollectionWhenDefinedMetaCustomizableSet() {
        // Arrange :
        String chainName = 'the-chain';
        Integer chainStep = 1;
        String data = 'data';

        insert new WiretapCustomization__c ( UserId__c = UserInfo.getUserId());

        Map<String,Object> notification = new Map<String,Object> {
            'eda__chainName' => chainName,
            'eda__chainStep' => chainStep,
            'data' => data
        };
        

        Integer expectedSize = 1;

        // Act
        Wiretap wireTap = new Wiretap();
        Process.PluginResult results = wireTap.invoke(new Process.PluginRequest(notification));
        List<Map<String,Object>> actualNotifications = Utility.convert(results);

        // prepare
        Integer actualSize = actualNotifications.size();

        // Assert
        System.assertEquals(expectedSize , actualSize );
    }
}