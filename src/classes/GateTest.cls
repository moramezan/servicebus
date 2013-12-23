@isTest  //-- no view of org data
private  class GateTest
{

    static testMethod void callingExecuteReturnsExpectedNotificationCollectionWhenGateItemsCountEqCount()
    {
        // Arrange :
        String  chainName          = 'the-chain';
        Decimal sequence           = 1;
        String  data               = 'data';
        Decimal count              =  3 ;


        GateGroup__c gateGroup      =  new GateGroup__c() ;
        insert gateGroup;
        Id           gateGroupId    = gateGroup.Id;

        Map<String,Object> notification = new Map<String,Object> {  'eda__chainName' => chainName,
                                                                    'eda__sequence' => sequence,
                                                                    'eda__gateGroupId' => gateGroupId,
                                                                    'eda__count' => count,
                                                                    'data' => data
                                                                    };


        List<GateItem__c> gateItems = new List<GateItem__c> ();
        integer i = 1;
        while(i <=  ( count - 1 ) )  // Adjust down by one (to allow the nth one inserted by execute() to equate with value in count)
        {
            Map<String,Object>  n = notification.clone();
            n.put('data' , 'x'+i);
            GateItem__c gateItem        = new GateItem__c( GateGroup__c =  gateGroupId , Notification__c = json.serializePretty(n) );
            gateItems.add(gateItem);
            i++;
        }
        insert  gateItems;



        Decimal  expectedSize              = 1;
        Id       expectedGateGroupId       = gateGroupId;
        Integer   expectedGateItemsSize     = (Integer) count;

        // Act
        Gate Gate = new Gate();
        List<Map<String,Object>> actualOutNotifications =  Gate.execute(notification);

        // prepare
        Decimal actualSize      = actualOutNotifications.size();
        Id   actualGateGroupId  = null;
        if (actualSize > 0)
        {
            Map<String,Object> actualNotification = actualOutNotifications[0];
            actualGateGroupId             = (Id) notification.get('id' );
        }
        integer actualGateItemsSize = [SELECT id FROM  GateItem__c].size();



        // Assert
        System.assertEquals(expectedSize , actualSize );
        System.assertEquals(actualGateGroupId , actualGateGroupId );
        System.assertEquals(expectedGateItemsSize , actualGateItemsSize );
    }
    
    
    static testMethod void callingExecuteReturnsExpectedNotificationCollectionWhenGateItemsCountNotEqCount()
    {
        // Arrange :
        String  chainName          = 'the-chain';
        Decimal sequence           = 1;
        String  data               = 'data';
        Decimal count              =  3 ;


        GateGroup__c gateGroup      =  new GateGroup__c() ;
        insert gateGroup;
        Id           gateGroupId    = gateGroup.Id;

        Map<String,Object> notification = new Map<String,Object> {  'eda__chainName' => chainName,
                                                                    'eda__sequence' => sequence,
                                                                    'eda__gateGroupId' => gateGroupId,
                                                                    'eda__count' => count,
                                                                    'data' => data
                                                                    };


        List<GateItem__c> gateItems = new List<GateItem__c> ();
        integer i = 1;
        while(i <=  ( count - 2 ) )  // Adjust down by TWO ( one inserted by execute() will NOT  equate with value in count)
        {
            Map<String,Object>  n = notification.clone();
            n.put('data' , 'x'+i);
            GateItem__c gateItem        = new GateItem__c( GateGroup__c =  gateGroupId , Notification__c = json.serializePretty(n) );
            gateItems.add(gateItem);
            i++;
        }
        insert  gateItems;



        Decimal  expectedSize              = 0;
        Integer   expectedGateItemsSize     = (Integer) ( count - 1) ;

        // Act
        Gate Gate = new Gate();
        List<Map<String,Object>> actualOutNotifications =  Gate.execute(notification);

        // prepare
        Decimal actualSize      = actualOutNotifications.size();
        integer actualGateItemsSize = [SELECT id FROM  GateItem__c].size();



        // Assert
        System.assertEquals(expectedSize , actualSize );
        System.assertEquals(expectedGateItemsSize , actualGateItemsSize );
    }
}