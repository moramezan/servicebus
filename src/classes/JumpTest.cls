@IsTest private class JumpTest {

    static testmethod void testJumpPervertsExecution() {
        //arrange
        Process__c jumpProcess = new Process__c(Name = 'Jump');
        insert jumpProcess;
        
        Process__c terminate = new Process__c(Name = 'Terminate');
        insert terminate;
        
        Sequence__c target = new Sequence__c(Name = 'target');
        insert target;
        insert new Step__c(Sequence__c = target.Id, Position__c = 1, Process__c = terminate.Id);
        
        JumpConfig__c config = new JumpConfig__c(Sequence__c = target.Id);
        insert config;
        
        Sequence__c origin = new Sequence__c(Name = 'origin');
        insert origin;
        insert new Step__c(Sequence__c = origin.Id, Position__c = 1, Process__c = jumpProcess.Id, ConfigId__c = config.Id);
        insert new Step__c(Sequence__c = origin.Id, Position__c = 2, Process__c = terminate.Id);
        
        
        Map<String,Object> parameters = new Map<String,Object>{
            'eda_StepConfigId' => config.Id,
            'eda_SequenceName' => 'origin',
            'eda_Position' => 1,
            'data' => 'herpderp'
        };
        
        //act
        Type reflector = Jump.class;
        List<Map<String,Object>> parametersList = new Broker.Wrapper(reflector, parameters).invokeMain().Outputs;
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = parametersList.size();
        System.assertEquals(expectedSize, actualSize);
        
        String expectedSequenceName = 'target';
        String actualSequenceName = (String)parametersList[0].get('eda_SequenceName');
        System.assertEquals(expectedSequenceName, actualSequenceName);
        
        Decimal expectedPosition = 0;
        Decimal actualPosition = (Decimal)parametersList[0].get('eda_Position');
        System.assertEquals(expectedPosition, actualPosition);
        
        String expectedPassThruData = 'herpderp';
        String actualPassThruData = (String)parametersList[0].get('data');
        System.assertEquals(expectedPassThruData, actualPassThruData);
    }
    
}