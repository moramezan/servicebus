@isTest public class BranchTest {
    
    static testMethod void testConfigureReturnsRightObjectType() {
        Branch process = new Branch();
        SObject config = process.configure();
        
        String actualType = String.valueOf(config);
        String expectedType = SObjectType.BranchConfiguration__c.Name;
        System.assert(actualType.startsWith(expectedType));
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
            'chainName' => origin.Name,
            'sequence' => 1,
            'configuration' => config.Id
        };
        
        //arrange processable
        Branch process = new Branch();
        
        //act
        List<Map<String,Object>> notifications = process.execute(notification);
        
        //assert
        Decimal expectedSize = 2;
        Decimal actualSize = notifications.size();
        System.assertEquals(expectedSize, actualSize);
        
        //act
        Map<String,Object> normalNotification = notifications[0]; //the normal notifications continues to the next step
        
        //asserts
        String expectedNormalChainName = origin.Name;
        String actualNormalChainName = (String)normalNotification.get('chainName');
        System.assertEquals(expectedNormalChainName, actualNormalChainName);
        
        Decimal expectedNormalSequence = 1;
        Decimal expectedActualSequence = (Decimal)normalNotification.get('sequence');
        System.assertEquals(expectedNormalSequence, expectedActualSequence);
        
        //act
        Map<String,Object> branchNotification = notifications[1]; //the branch notification goes to the top of another chain
        
        //asserts
        String expectedBranchChainName = target.Name;
        String actualBranchChainName = (String)branchNotification.get('chainName');
        System.assertEquals(expectedBranchChainName, actualBranchChainName);
        
        Decimal expectedBranchSequence = 0;
        Decimal actualBranchSequence = (Decimal)branchNotification.get('sequence');
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
            'chainName' => chain.Name,
            'sequence' => 1,
            'configuration' => config.Id
        };
        
        //arrange process
        Branch process = new Branch();
        
        //arrange exception
        Boolean exceptionThrown = false;
        
        //act
        try {
            List<Map<String,Object>> notifications = process.execute(notification);
        } catch (Exception e) {
            exceptionThrown = true;
            System.assert(e instanceof Branch.BranchException);
        }
        
        //assert
        System.assert(exceptionThrown);
    }

}