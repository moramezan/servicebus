@isTest private class JumpTest {

    static testMethod void testProcessIsDescribed() {
        Jump jump = new Jump();
        System.assertNotEquals(null, jump.describe().Name);
        System.assertNotEquals(null, jump.describe().Description);
        System.assertNotEquals(null, jump.describe().Tag);
    }
    
    
    static testMethod void testJumpPervertsExecution() {
        //arrange
        Process__c jump = new Process__c(Name = 'Jump');
        insert jump;
        
        Process__c sink = new Process__c(Name = 'Sink');
        insert sink;
        
        Chain__c target = new Chain__c(Name = 'target');
        insert target;
        insert new ChainStep__c(Chain__c = target.Id, Sequence__c = 1, Process__c = sink.Id);
        
        JumpConfiguration__c configuration = new JumpConfiguration__c(Chain__c = target.Id);
        insert configuration;
        
        Chain__c origin = new Chain__c(Name = 'origin');
        insert origin;
        insert new ChainStep__c(Chain__c = origin.Id, Sequence__c = 1, Process__c = jump.Id, Configuration__c = configuration.Id);
        insert new ChainStep__c(Chain__c = origin.Id, Sequence__c = 2, Process__c = sink.Id);
        
        
        Map<String,Object> notification = new Map<String,Object>{
            'eda__configurable' => configuration.Id,
            'eda__chainName' => 'origin',
            'eda__sequence' => 1,
            'data' => 'herpderp'
        };
        
        //act
        Jump process = new Jump();
        List<Map<String,Object>> notifications = Utility.convert(process.invoke(new Process.PluginRequest(notification)));
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = notifications.size();
        System.assertEquals(expectedSize, actualSize);
        
        String expectedChainName = 'target';
        String actualChainName = (String)notifications[0].get('eda__chainName');
        System.assertEquals(expectedChainName, actualChainName);
        
        Decimal expectedSequence = 0;
        Decimal actualSequence = (Decimal)notifications[0].get('eda__sequence');
        System.assertEquals(expectedSequence, actualSequence);
        
        String expectedPassThruData = 'herpderp';
        String actualPassThruData = (String)notifications[0].get('data');
        System.assertEquals(expectedPassThruData, actualPassThruData);
    }
    
}