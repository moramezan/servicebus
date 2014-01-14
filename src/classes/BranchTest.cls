@isTest public class BranchTest {
    
    static testMethod void testConfigureReturnsRightObjectType() {
         // Arrange 
        Branch process = new Branch();
        String className = String.valueOf(process).split(':')[0]; 
        Map<string, Object> meta = Utility.meta(className);  
            
        // Act 
        String actualDescription = (String) meta.get('configurable');
        
        // Assert
        String expectedDescription = Schema.SObjectType.BranchConfiguration__c.Name;
        System.assertEquals(expectedDescription, actualDescription);
    }

    static testMethod void testBoomerangDropped() {
        Chain__c origin = new Chain__c(Name = 'origin');
        insert origin;
        
        Chain__c target = new Chain__c(Name = 'target');
        insert target;
        
        BranchConfiguration__c config = new BranchConfiguration__c(Chain__c = target.Id);
        insert config;
        
        Map<String,Object> notification = new Map<String,Object>{
            'eda__configuration' => config.Id,
            'eda__boomerangChainStepIds' => new List<Id>{'000000000000000AAA'}
        };
        
        Branch branch = new Branch();
        List<Map<String,Object>> notifications = Utility.convert(branch.invoke(new Process.PluginRequest(notification)));
        
        List<Object> expectedIds = null;
        List<Object> actualIds = (List<Object>)notifications[1].get('eda__boomerangChainStepIds');
        System.assertEquals(expectedIds, actualIds);
    }
    
    static testMethod void testTwoNotificationsReturned() {
        //arrange chains
        Chain__c origin = new Chain__c(Name = 'originChain');
        Chain__c target = new Chain__c(Name = 'targetChain');
        insert origin;
        insert target;
        
        //arrange config
        BranchConfiguration__c config = new BranchConfiguration__c(Chain__c = target.Id);
        insert config;
        
        //arrange notification
        Map<String,Object> notification = new Map<String,Object>{
            'eda__chainName' => origin.Name,
            'eda__sequence' => 1,
            'eda__configuration' => config.Id
        };
        
        //arrange processable
        Branch process = new Branch();
        
        //act
        Process.PluginResult result = process.invoke(new Process.PluginRequest(notification));
        List<Map<String,Object>> notifications = Utility.convert(result);
        
        //assert
        Decimal expectedSize = 2;
        Decimal actualSize = notifications.size();
        System.assertEquals(expectedSize, actualSize);
        
        //act
        Map<String,Object> normalNotification = notifications[0]; //the normal notifications continues to the next step
        
        //asserts
        String expectedNormalChainName = origin.Name;
        String actualNormalChainName = (String)normalNotification.get('eda__chainName');
        System.assertEquals(expectedNormalChainName, actualNormalChainName);
        
        Decimal expectedNormalSequence = 1;
        Decimal expectedActualSequence = (Decimal)normalNotification.get('eda__sequence');
        System.assertEquals(expectedNormalSequence, expectedActualSequence);
        
        //act
        Map<String,Object> branchNotification = notifications[1]; //the branch notification goes to the top of another chain
        
        //asserts
        String expectedBranchChainName = target.Name;
        String actualBranchChainName = (String)branchNotification.get('eda__chainName');
        System.assertEquals(expectedBranchChainName, actualBranchChainName);
        
        Decimal expectedBranchSequence = 0;
        Decimal actualBranchSequence = (Decimal)branchNotification.get('eda__sequence');
        System.assertEquals(expectedBranchSequence, actualBranchSequence);
    }
    
    static testMethod void testInfiniteLoopFuckupGetsCaught() {
        //arrange chains
        Chain__c chain = new Chain__c(Name = 'originChain');
        insert chain;
        
        //arrange config
        BranchConfiguration__c config = new BranchConfiguration__c(Chain__c = chain.Id);
        insert config;
        
        //arrange notification
        Map<String,Object> notification = new Map<String,Object>{
            'eda__chainName' => chain.Name,
            'eda__sequence' => 1,
            'eda__configuration' => config.Id
        };
        
        //arrange process
        Branch process = new Branch();
        
        //arrange exception
        Boolean exceptionThrown = false;
        
        //act
        try {
            Process.PluginResult result = process.invoke(new Process.PluginRequest(notification));
            List<Map<String,Object>> notifications = Utility.convert(result);
        } catch (Exception e) {
            exceptionThrown = true;
            System.assert(e instanceof Branch.BranchException);
        }
        
        //assert
        System.assert(exceptionThrown);
    }

}