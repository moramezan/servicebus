@isTest public class BoomerangTest {
    
    static testMethod void testConfigurationReturnsObjectType() {
        // Arrange 
        Boomerang process = new Boomerang();
        String className = String.valueOf(process).split(':')[0]; 
        Map<string, Object> meta = Utility.meta(className);  
            
        // Act 
        String actualDescription = (String) meta.get('configurable');
        
        // Assert
        String expectedDescription = Schema.SObjectType.BoomerangConfiguration__c.Name;
        System.assertEquals(expectedDescription, actualDescription);
    }

    static testMethod void testNotificationIsRedirected() {
        // prepare process
        Process__c processOrigin =  new Process__c(Name = 'Boomerang' );
        Process__c processTarget =  new Process__c(Name = 'Sink' );   
        insert processOrigin;
        insert processTarget;  

        //prepare chains in db
        Chain__c origin = new Chain__c(Name = 'originChain');
        insert origin;
        ChainStep__c originChainStep = new ChainStep__c(Chain__c = origin.Id, Sequence__c = 1, Process__c = processOrigin.Id);
        insert originChainStep;
        
        Chain__c target = new Chain__c(Name = 'targetChain');
        insert target;
        ChainStep__c targetChainStep = new ChainStep__c(Chain__c = target.Id, Sequence__c = 1, Process__c = processTarget.Id);
        insert targetChainStep;
        
        //prepare configuration in db
        BoomerangConfiguration__c config = new BoomerangConfiguration__c(Chain__c = target.Id);
        insert config;
        
        //prepare notification
        Process.PluginRequest request = new Process.PluginRequest(new Map<String,Object>{
            'eda__chainName' => 'originChain',
            'eda__sequence' => 1,
            'eda__configuration' => config.Id
        });
        
        //act
        Boomerang process = new Boomerang();
        Process.PluginResult result = process.invoke(request);
        List<Map<String,Object>> notifications = Utility.convert(result);
        
        //asserts
        Decimal expectedSize = 1;
        Decimal actualSize = notifications.size();
        System.assertEquals(expectedSize, actualSize);
        
        String expectedChainName = 'targetChain';
        String actualChainName = (String)notifications[0].get('eda__chainName');
        System.assertEquals(expectedChainName, actualChainName);
        
        Decimal expectedSequence = 0;
        Decimal actualSequence = (Decimal)notifications[0].get('eda__sequence');
        System.assertEquals(expectedSequence, actualSequence);

        String expectedList = '["' + originChainStep.Id + '"]';
        String actualList = System.Json.serialize(notifications[0].get('eda__boomerangChainStepIds'));
        System.assertEquals(expectedList, actualList);
    }
    
}