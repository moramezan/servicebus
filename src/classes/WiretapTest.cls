@isTest  //-- no view of org data
private  class WiretapTest
{

    static testMethod void callingExecuteReturnsExpectedNotificationCollection()
    {
        // Arrange :
        String  chainName      = 'the-chain';
        Integer chainStep      = 1;
        String  data           = 'data';

        Map<String,Object> notification = new Map<String,Object> {  'eda__chainName' => chainName, 
                                                        'eda__chainStep' => chainStep, 
                                                        'data' => data
                                                        };
        

        Integer expectedSize = 1;

        // Act
        Wiretap wireTap = new Wiretap();
        List<Map<String,Object>> actualNotifications =  wireTap.execute(notification);

        // prepare
        Integer actualSize = actualNotifications.size();

        // Assert
        System.assertEquals(expectedSize , actualSize );
    }
}