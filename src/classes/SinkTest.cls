@isTest  //-- no view of org data
private  class SinkTest
{

    static testMethod void callingExecuteReturnsExpectedNotificationCollectionWhenBoomerangAttribsDefinedOnNotification()
    {
        // Arrange :
        String  chainName          = 'the-chain';
        Decimal sequence           = 1;
        String  data               = 'data';
        String  boomerangChainName = 'boomerang-chain';
        Decimal boomerangSequence  = 2;
 

        Map<String,Object> notification = new Map<String,Object> {  'chainName' => chainName,
                                                                    'sequence' => sequence,
                                                                    'boomerangChainName' => boomerangChainName ,
                                                                    'boomerangSequence'  => boomerangSequence ,
                                                                    'data' => data
                                                                    };


        Decimal expectedSize = 1;
        String  expectedChainName   = boomerangChainName;
        Decimal expectedSequence    = boomerangSequence;

        // Act
        Sink Sink = new Sink();
        List<Map<String,Object>> actualOutNotifications =  Sink.execute(notification);

        // prepare
        Decimal actualSize = actualOutNotifications.size();
        String  actualChainName         = null;
        Decimal actualSequence          = null;
        if (actualSize > 0)
        {
            Map<String,Object> actualNotification = actualOutNotifications[0];
            actualChainName         = (String)actualNotification.get('chainName');
            actualSequence          = (Decimal)actualNotification.get('sequence');
        }


        // Assert
        System.assertEquals(expectedSize , actualSize );
        System.assertEquals(expectedChainName , actualChainName );
        System.assertEquals(expectedSequence  , actualSequence  );
    }
    
    
    static testMethod void callingExecuteReturnsExpectedNotificationCollectionWhenNoBoomerangAttribsDefinedOnNotification()
    {
        // Arrange :
        String  chainName          = 'the-chain';
        Decimal sequence           = 1;
        String  data               = 'data';
 
 

        Map<String,Object> notification = new Map<String,Object> {  'chainName' => chainName,
                                                                    'sequence' => sequence,
                                                                    'data' => data
                                                                    };


        Decimal expectedSize = 0;
 

        // Act
        Sink Sink = new Sink();
        List<Map<String,Object>> actualOutNotifications =  Sink.execute(notification);

        // prepare
        Decimal actualSize = actualOutNotifications.size();
 


        // Assert
        System.assertEquals(expectedSize , actualSize );
    }
      
    
    
    
}