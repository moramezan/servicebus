@IsTest private class JumpTest {
     
    static testmethod void hasTheCorrectLimits() {
        //assert
        Integer expectedLimits = 100;
        Integer actualLimits = new Jump.ESB().Limits;
        System.assertEquals(expectedLimits, actualLimits);
    }
 
    
    static testmethod void testJumpPervertsExecution() {
        //arrange
        Sequence__c target = new Sequence__c(Name = 'target');
        insert target;
        StepModel.generateOne(target.Name, Terminate.class.getName());
        
        JumpConfig__c config = new JumpConfig__c(Sequence__c = target.Id);
        insert config;
        
        Sequence__c origin = new Sequence__c(Name = 'origin');
        insert origin;
        StepModel.generateOne(origin.Name, Jump.class.getName());
        StepModel.generateOne(origin.Name, Terminate.class.getName());
        
        
        Map<String,Object> parameters = new Map<String,Object>{
            'esb__StepConfig' => config,
            '__SequenceName' => 'origin',
            '__Position' => 1,
            'data' => 'herpderp'
        };
        
        //act
        ProcessModel.BaseProcess process = new Jump();
        List<Map<String,Object>> parametersList = process.execute(parameters);
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = parametersList.size();
        System.assertEquals(expectedSize, actualSize);
        
        String expectedSequenceName = 'target';
        String actualSequenceName = (String)parametersList[0].get('__SequenceName');
        System.assertEquals(expectedSequenceName, actualSequenceName);
        
        Decimal expectedPosition = 0;
        Decimal actualPosition = (Decimal)parametersList[0].get('__Position');
        System.assertEquals(expectedPosition, actualPosition);
        
        String expectedPassThruData = 'herpderp';
        String actualPassThruData = (String)parametersList[0].get('data');
        System.assertEquals(expectedPassThruData, actualPassThruData);
    }
    
}