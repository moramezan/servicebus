@isTest  //-- no view of org data
private  class MarkTest
{


    static testMethod void callingExecuteReturnsExpectedNotificationCollectio()
    {
        // Arrange :
        String  chainName          = 'the-chain';
        Decimal sequence           = 1;
         String  data              = 'data';

        Map<String,Object> notification = new Map<String,Object> {  'eda__chainName' => chainName,
                                                                    'eda__sequence' => sequence,
                                                                    'data' => data
                                                                    };

        Decimal  expectedSize = 1;
        Integer  expectedGateGroupSize     = 1;
        Decimal  expectedMarkCount         = 0;
        Boolean  expectedGateGroupIdFlag   = true;

        // Act
        Mark mark = new Mark();
        Process.PluginResult results = mark.invoke(new Process.PluginRequest(notification));
        List<Map<String,Object>> actualOutNotifications = Utility.convert(results);

        // prepare
        Decimal actualSize = actualOutNotifications.size();
        Decimal  actualMarkCount           = null;
        Boolean   actualGateGroupIdFlag         = false;
        if (actualSize > 0)
        {
            Map<String,Object> actualNotification = actualOutNotifications[0];
            actualMarkCount             = (Decimal) notification.get('eda__markCount' );
            actualGateGroupIdFlag           =    ( notification.get('eda__gateGroupId' ) != null);
        }
        integer actualGateGroupSize = [SELECT id FROM  GateGroup__C].size();

        // Assert
        System.assertEquals(expectedSize , actualSize );
        System.assertEquals(expectedGateGroupSize , actualGateGroupSize );
        System.assertEquals(expectedMarkCount    , actualMarkCount        );
        System.assertEquals(expectedGateGroupIdFlag  , actualGateGroupIdFlag      );
    }
}