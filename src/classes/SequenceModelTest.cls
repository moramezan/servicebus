@IsTest private class SequenceModelTest {
    
    @TestSetup static void testSetup() {
        new PostInstallHandler().upsertNamespaceSetting();
    }
    
    private static testmethod void  callingFetchStepsReturnsExpectedStepCollection() {
        // arrange
        String sequenceName = 'theSequence';
        Sequence__c soSequence = new Sequence__c(Name = sequenceName);
        insert soSequence;
        Id soSequenceId = soSequence.Id;

        Step__c stepA1 = SequenceModel.fromName(soSequence.Name).appendStep(Subscribe.class);
        Step__c stepA2 = SequenceModel.fromName(soSequence.Name).appendStep(Publish.class);
        Step__c stepA3 = SequenceModel.fromName(soSequence.Name).appendStep(Terminate.class);
        Integer positionA1 = stepA1.Position__c.intValue();
        Integer positionA2 = stepA2.Position__c.intValue();
        Integer positionA3 = stepA3.Position__c.intValue();

        // act
        SequenceModel sequence = SequenceModel.fromName(soSequence.Name);
        
        // assemble
        List<Map<String,Object>> soSteps = sequence.stepSetModel().toDtos();
        Integer actualStepCount = soSteps.size();

        // assert
        
        Integer expectedStepCount = 3;
        System.assertEquals( expectedStepCount , actualStepCount  );
    }
    
    private static testmethod void callingAppendStepAddStepWithExpectedServiceInExpectedPosition() {
        // arrange
        String sequenceName = 'theSequence';
        Sequence__c soSequence = new Sequence__c(Name = sequenceName);
        insert soSequence;
        Id soSequenceId = soSequence.Id;

        // act
        Step__c actualStep = SequenceModel.fromName(soSequence.Name).appendStep(Subscribe.class);
        
        // assemble
        List<Step__c> soSteps = [SELECT Name, ApexClassName__c, Position__c FROM Step__c WHERE SequenceName__c = :soSequence.Name];
        Integer actualStepCount  = soSteps.size();
        // SObject soStep = actualStep.getRecord();
        String actualServiceName;
        Integer actualPosition;
        if (soSteps.size() > 0) {
            actualServiceName = soSteps[0].ApexClassName__c;
            actualPosition = soSteps[0].Position__c.intValue();
        }
        
        // assert
        Integer expectedPosition = 1;
        System.assertEquals( expectedPosition , actualPosition  );
        String expectedServiceName = Subscribe.class.getName();
        System.assertEquals( expectedServiceName , actualServiceName  );
        Integer expectedStepCount = 1;
        System.assertEquals( expectedStepCount , actualStepCount  );
    }

    private static testmethod void callingTerminateAddsTerminateStepIfNoTerminateStepExists() {
        // arrange
        String sequenceName = 'theSequence';
        Sequence__c soSequence = new Sequence__c(Name = sequenceName);
        insert soSequence;
        Id soSequenceId = soSequence.Id;

        // act
        SequenceModel sequence = SequenceModel.fromName(soSequence.Name);
        sequence.terminateIfNeeded();
        
        // assemble
        List<Step__c> soSteps = [SELECT Name, ApexClassName__c, Position__c FROM Step__c WHERE SequenceName__c = :soSequence.Name];
        Integer actualStepCount  = soSteps.size();
        String actualServiceName;
        Integer actualPosition;
        if (soSteps.size() > 0) {
            actualServiceName = soSteps[0].ApexClassName__c;
            actualPosition = soSteps[0].Position__c.intValue();
        }
        
        // assert
        Integer expectedPosition = 1;
        System.assertEquals( expectedPosition , actualPosition  );
        String expectedServiceName = Terminate.class.getName();
        System.assertEquals( expectedServiceName , actualServiceName  );
        Integer expectedStepCount = 1;
        System.assertEquals( expectedStepCount , actualStepCount  );
    }
    
    private static testmethod void callingTerminateDoesNotAddTerminateStepIfTerminateStepExists() {
        // arrange
        String sequenceName = 'theSequence';
        Sequence__c soSequence = new Sequence__c(Name = sequenceName);
        insert soSequence;
        Id soSequenceId = soSequence.Id;

        // act
        SequenceModel sequence = SequenceModel.fromName(soSequence.Name);
        sequence.terminateIfNeeded(); // once ( terminate will now exist)
        sequence.terminateIfNeeded(); // and again!
        
        // assemble
        List<Step__c> soSteps = [SELECT Name, ApexClassName__c, Position__c FROM Step__c WHERE SequenceName__c = :soSequence.Name];
        Integer actualStepCount  = soSteps.size();
        String actualServiceName;
        Integer actualPosition;
        if (soSteps.size() > 0) {
            actualServiceName = soSteps[0].ApexClassName__c;
            actualPosition = soSteps[0].Position__c.intValue();
        }
        
        // assert
        Integer expectedPosition = 1;
        System.assertEquals( expectedPosition , actualPosition  );
        String expectedServiceName = Terminate.class.getName();
        System.assertEquals( expectedServiceName , actualServiceName  );
        Integer expectedStepCount = 1;
        System.assertEquals( expectedStepCount , actualStepCount  );
    }
    
    private static testmethod void callingDeleteStepWillDeleteStepOnThisSequence() {
        // arrange
        String sequenceNameA = 'theSequenceA';
        Sequence__c soSequenceA = new Sequence__c(Name = sequenceNameA);
        insert soSequenceA;
        Id soSequenceAId = soSequenceA.Id;
        Step__c stepA1 = SequenceModel.fromName(soSequenceA.Name).appendStep(Subscribe.class);
        Step__c stepA2 = SequenceModel.fromName(soSequenceA.Name).appendStep(Terminate.class);
 

        // act
        SequenceModel sequenceA = SequenceModel.fromName(soSequenceA.Name);
        SequenceModel.fromName(sequenceNameA).destroyStep(stepA1.Name);
 
        
        // assemble
        List<Step__c> soSteps = [SELECT Name, ApexClassName__c, Position__c FROM Step__c];
        Integer actualStepsCount  = soSteps.size();
        String actualServiceName;
        Integer actualPosition;
        if (soSteps.size() > 0) {
            actualServiceName = soSteps[0].ApexClassName__c;
            actualPosition = soSteps[0].Position__c.intValue();
        }
   
        // assert
        Integer expectedPosition = 1;
        System.assertEquals( expectedPosition , actualPosition  );
        String expectedServiceName = Terminate.class.getName();
        System.assertEquals( expectedServiceName , actualServiceName  );
        Integer expectedStepCount = 1;
        System.assertEquals( expectedStepCount , actualStepsCount  );
    }
}