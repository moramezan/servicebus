@IsTest private class SequenceModelTest {
            
    private static testmethod void  callingFetchStepsReturnsExpectedStepCollection() {
        // arrange
        String sequenceName = 'theSequence';
        Sequence__c soSequence = new Sequence__c(Name = sequenceName);
        insert soSequence;
        Id soSequenceId = soSequence.Id;

        Step__c stepA1 = StepModel.generateOne(soSequence.Name, Subscribe.class.getName());
        Step__c stepA2 = StepModel.generateOne(soSequence.Name, Publish.class.getName());
        Step__c stepA3 = StepModel.generateOne(soSequence.Name, Terminate.class.getName());
        Decimal positionA1 = stepA1.Position__c;
        Decimal positionA2 = stepA2.Position__c;
        Decimal positionA3 = stepA3.Position__c;

        // act
        SequenceModel sequence = SequenceModel.fromName(soSequence.Name);
        
        // assemble
        List<Step__c> soSteps = sequence.fetchSteps();
        Integer actualStepCount = soSteps.size();

        // assert
        
        Integer expectedStepCount = 3;
        System.assertEquals( expectedStepCount , actualStepCount  );
    }
    
    private static testmethod void callingAppendStepAddStepWithExpectedProcessInExpectedPosition() {
        // arrange
        String sequenceName = 'theSequence';
        Sequence__c soSequence = new Sequence__c(Name = sequenceName);
        insert soSequence;
        Id soSequenceId = soSequence.Id;

        // act
        SequenceModel sequence = SequenceModel.fromName(soSequence.Name);
        Step__c actualStep = sequence.appendStep(Subscribe.class.getName());
        
        // assemble
        List<Step__c> soSteps = [SELECT Id, Name, FullyQualifiedClassName__c, Position__c FROM Step__c WHERE SequenceName__c = :soSequence.Name];
        Integer actualStepCount  = soSteps.size();
        // SObject soStep = actualStep.getRecord();
        String actualProcessName;
        Decimal actualPosition;
        if (soSteps.size() > 0) {
            actualProcessName = soSteps[0].FullyQualifiedClassName__c;
            actualPosition = soSteps[0].Position__c;
        }
        
        // assert
        Decimal expectedPosition = 1;
        System.assertEquals( expectedPosition , actualPosition  );
        String expectedProcessName = Subscribe.class.getName();
        System.assertEquals( expectedProcessName , actualProcessName  );
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
        sequence.terminate();
        
        // assemble
        List<Step__c> soSteps = [SELECT Id, Name, FullyQualifiedClassName__c, Position__c FROM Step__c WHERE SequenceName__c = :soSequence.Name];
        Integer actualStepCount  = soSteps.size();
        String actualProcessName;
        Decimal actualPosition;
        if (soSteps.size() > 0) {
            actualProcessName = soSteps[0].FullyQualifiedClassName__c;
            actualPosition = soSteps[0].Position__c;
        }
        
        // assert
        Decimal expectedPosition = 1;
        System.assertEquals( expectedPosition , actualPosition  );
        String expectedProcessName = Terminate.class.getName();
        System.assertEquals( expectedProcessName , actualProcessName  );
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
        sequence.terminate(); // once ( terminate will now exist)
        sequence.terminate(); // and again!
        
        // assemble
        List<Step__c> soSteps = [SELECT Id, Name, FullyQualifiedClassName__c, Position__c FROM Step__c WHERE SequenceName__c = :soSequence.Name];
        Integer actualStepCount  = soSteps.size();
        String actualProcessName;
        Decimal actualPosition;
        if (soSteps.size() > 0) {
            actualProcessName = soSteps[0].FullyQualifiedClassName__c;
            actualPosition = soSteps[0].Position__c;
        }
        
        // assert
        Decimal expectedPosition = 1;
        System.assertEquals( expectedPosition , actualPosition  );
        String expectedProcessName = Terminate.class.getName();
        System.assertEquals( expectedProcessName , actualProcessName  );
        Integer expectedStepCount = 1;
        System.assertEquals( expectedStepCount , actualStepCount  );
    }
    
    private static testmethod void callingDeleteStepWillDeleteStepOnThisSequence() {
        // arrange
        String sequenceNameA = 'theSequenceA';
        Sequence__c soSequenceA = new Sequence__c(Name = sequenceNameA);
        insert soSequenceA;
        Id soSequenceAId = soSequenceA.Id;
        Step__c stepA1 = StepModel.generateOne(soSequenceA.Name, Subscribe.class.getName());
        Step__c stepA2 = StepModel.generateOne(soSequenceA.Name, Terminate.class.getName());
 

        // act
        Id deletedStepId =  stepA1.Id;
        SequenceModel sequenceA = SequenceModel.fromName(soSequenceA.Name);
        StepSetModel actualSteps = sequenceA.destroySteps(new Set<Id>{deletedStepId});
 
        
        // assemble
        List<Step__c> soSteps = [SELECT Id, Name, FullyQualifiedClassName__c, Position__c FROM Step__c];
        Integer actualStepsCount  = soSteps.size();
        String actualProcessName;
        Decimal actualPosition;
        if (soSteps.size() > 0) {
            actualProcessName = soSteps[0].FullyQualifiedClassName__c;
            actualPosition = soSteps[0].Position__c;
        }
   
        // assert
        Decimal expectedPosition = 1;
        System.assertEquals( expectedPosition , actualPosition  );
        String expectedProcessName = Terminate.class.getName();
        System.assertEquals( expectedProcessName , actualProcessName  );
        Integer expectedStepCount = 1;
        System.assertEquals( expectedStepCount , actualStepsCount  );
    }
}