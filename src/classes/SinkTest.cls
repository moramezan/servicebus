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

        Chain__c chain = new Chain__c(Name = boomerangChainName);
        insert chain;
        
        Process__c process = new Process__c(Name = 'Boomerang');
        insert process;
        
        ChainStep__c chainStep = new ChainStep__c ( Chain__c = chain.Id, Process__c = process.Id, Sequence__c = boomerangSequence);
        insert chainStep;

        Map<String,Object> notification = new Map<String,Object> {  'eda__chainName' => chainName,
                                                                    'eda__sequence' => sequence,
                                                                    'eda__boomerangChainStepId' => chainStep.Id ,
                                                                    'data' => data
                                                                    };


        Decimal expectedSize = 1;
        String  expectedChainName   = boomerangChainName;
        Decimal expectedSequence    = boomerangSequence;

        // Act
        Sink sink = new Sink();
        Process.PluginResult results = sink.invoke(new Process.PluginRequest(notification));
        List<Map<String,Object>> actualOutNotifications =  Utility.convert(results);

        // prepare
        Decimal actualSize = actualOutNotifications.size();
        String  actualChainName         = null;
        Decimal actualSequence          = null;
        if (actualSize > 0)
        {
            Map<String,Object> actualNotification = actualOutNotifications[0];
            actualChainName         = (String)actualNotification.get('eda__chainName');
            actualSequence          = (Decimal)actualNotification.get('eda__sequence');
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
 
 

        Map<String,Object> notification = new Map<String,Object> {  'eda__chainName' => chainName,
                                                                    'eda__sequence' => sequence,
                                                                    'data' => data
                                                                    };


        Decimal expectedSize = 0;
 

        // Act
        Sink sink = new Sink();
        Process.PluginResult results = sink.invoke(new Process.PluginRequest(notification));
        List<Map<String,Object>> actualOutNotifications =  Utility.convert(results);

        // prepare
        Decimal actualSize = actualOutNotifications.size();
 


        // Assert
        System.assertEquals(expectedSize , actualSize );
    }
      
    
    
    
}