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
        
        Process__c terminate = new Process__c(Name = 'Terminate');
        insert terminate;
        
        Chain__c target = new Chain__c(Name = 'target');
        insert target;
        insert new Step__c(Chain__c = target.Id, Position__c = 1, Process__c = terminate.Id);
        
        JumpConfiguration__c configuration = new JumpConfiguration__c(Chain__c = target.Id);
        insert configuration;
        
        Chain__c origin = new Chain__c(Name = 'origin');
        insert origin;
        insert new Step__c(Chain__c = origin.Id, Position__c = 1, Process__c = jump.Id, ConfigurationId__c = configuration.Id);
        insert new Step__c(Chain__c = origin.Id, Position__c = 2, Process__c = terminate.Id);
        
        
        Map<String,Object> parameters = new Map<String,Object>{
            'eda__configurable' => configuration.Id,
            'eda__chainName' => 'origin',
            'eda__position' => 1,
            'data' => 'herpderp'
        };
        
        //act
        Jump process = new Jump();
        List<Map<String,Object>> parametersList = Utility.convert(process.invoke(new Process.PluginRequest(parameters)));
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = parametersList.size();
        System.assertEquals(expectedSize, actualSize);
        
        String expectedChainName = 'target';
        String actualChainName = (String)parametersList[0].get('eda__chainName');
        System.assertEquals(expectedChainName, actualChainName);
        
        Decimal expectedPosition = 0;
        Decimal actualPosition = (Decimal)parametersList[0].get('eda__position');
        System.assertEquals(expectedPosition, actualPosition);
        
        String expectedPassThruData = 'herpderp';
        String actualPassThruData = (String)parametersList[0].get('data');
        System.assertEquals(expectedPassThruData, actualPassThruData);
    }
    
}