@IsTest private class JumpTest {
     
    static testmethod void hasTheCorrectLimits() {
        //arrange
        ApexClassModel.Summary summary = new ApexClassModel.Summary(Jump.class);
        
        //assert
        Integer expectedLimits = 50; //max sync limit
        Integer actualLimits = summary.Limits;
        System.assertEquals(expectedLimits, actualLimits);
    }


   static testmethod void withinSystemLimits() {
        //arrange
        ApexClassModel.Summary summary = new ApexClassModel.Summary(Jump.class);
        
        //arrange
        Sequence__c target = new Sequence__c(Name = 'Target');
        insert target;
        SequenceModel.fromName(target.Name).appendStep(Terminate.class);
        
        JumpConfig__c config = new JumpConfig__c(Sequence__c = target.Id);
        insert config;
        
        Sequence__c origin = new Sequence__c(Name = 'Origin');
        insert origin;
        SequenceModel.fromName(origin.Name).appendStep(Jump.class);
        SequenceModel.fromName(origin.Name).appendStep(Terminate.class);
        
        
        Map<String,Object> inputEvent = new Map<String,Object>{
            'StepConfigId' => config.Id,
            'Route' => 'Origin#1',
            'data' => 'herpderp'
        };


        //act
        Test.startTest();
        Integer limits = summary.Limits;
        Integer counter = 0;
        for (Integer i = 0; i < limits; i++) {
            ApexClassModel.BaseProcess process = new Jump();
            List<Map<String,Object>> outputs = process.test(inputEvent);
            counter++;
        }
        Test.stopTest();

        //assert
        System.assertEquals(limits, counter, 'Limit not reached.');
   }

    
    static testmethod void testJumpPervertsExecution() {
        //arrange sequences
        Sequence__c origin = new Sequence__c(Name = 'Origin');
        insert origin;
        
        Sequence__c target = new Sequence__c(Name = 'Target');
        insert target;
        
        //arrange steps
        Step__c step = SequenceModel.fromId(origin.Id).appendStep(Jump.class);
        Id stepConfigId = new StepModel(step).upsertConfig();
        
        JumpConfig__c stepConfig = new JumpConfig__c(Id = stepConfigId, Sequence__c = target.Id);
        update stepConfig;
        
        //arrange input event
        Map<String,Object> inputEvent = new Map<String,Object>{
            'StepConfigId' => stepConfig.Id,
            'Route' => 'Origin#1',
            'data' => 'herpderp'
        };
        
        //act
        ApexClassModel.BaseProcess process = new Jump();
        List<Map<String,Object>> outputEvents = process.test(inputEvent);
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize);
        
        String expectedSequence = 'Target#0';
        String actualSequence = (String)outputEvents[0].get('Route');
        System.assertEquals(expectedSequence, actualSequence, 'Wrong sequence.');
        
        String expectedPassThruData = 'herpderp';
        String actualPassThruData = (String)outputEvents[0].get('data');
        System.assertEquals(expectedPassThruData, actualPassThruData);
    }
    
}