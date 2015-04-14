@IsTest private class SequenceModelTest {
            
    private static testmethod void  callingFetchStepsReturnsExpectedStepCollection() {
        // arrange
        Process__c publishProcess = ProcessModel.generateOne(Publish.class);
        Process__c terminateProcess = ProcessModel.generateOne(Terminate.class);
        Process__c subscribeProcess = ProcessModel.generateOne(Subscribe.class);
         
        String sequenceName = 'theSequence';   
        Sequence__c soSequence = new Sequence__c(Name = sequenceName);
        insert soSequence;
        Id soSequenceId = soSequence.Id;

        Step__c stepA1 = StepModel.generateOne(soSequenceId, subscribeProcess.Id);
        Step__c stepA2 = StepModel.generateOne(soSequenceId, publishProcess.Id);
        Step__c stepA3 = StepModel.generateOne(soSequenceId, terminateProcess.Id);
        Decimal positionA1 = stepA1.Position__c;
        Decimal positionA2 = stepA2.Position__c;
        Decimal positionA3 = stepA3.Position__c;

        // act 
        SequenceModel sequence = new SequenceModel(soSequence);
        StepSetModel actualSteps  = sequence.fetchSteps();
        
        // assemble
        List<Step__c> soSteps = actualSteps.getRecords();
        Integer actualStepCount = soSteps.size();

        // assert
        
        Integer expectedStepCount = 3;
        System.assertEquals( expectedStepCount , actualStepCount  );
    }
    
    private static testmethod void callingAppendStepAddStepWithExpectedProcessInExpectedPosition() {
        // arrange
        Process__c subscribeProcess = ProcessModel.generateOne(Subscribe.class);

        String sequenceName = 'theSequence';   
        Sequence__c soSequence = new Sequence__c(Name = sequenceName);
        insert soSequence;
        Id soSequenceId = soSequence.Id;

        // act 
        SequenceModel sequence = new SequenceModel(soSequence);
        StepModel actualStep = sequence.appendStep(subscribeProcess.Id);
        
        // assemble
        List<Step__c> soSteps = [SELECT Id, Name, Process__r.FullyQualifiedClassName__c, Position__c FROM Step__c WHERE Sequence__c = :soSequenceId];
        Integer actualStepCount  = soSteps.size();
        // SObject soStep = actualStep.getRecord();
        String actualProcessName;
        Decimal actualPosition; 
        if (soSteps.size() > 0) {
            actualProcessName = soSteps[0].Process__r.FullyQualifiedClassName__c;
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
        Process__c terminateProcess = ProcessModel.generateOne(Terminate.class);

        String sequenceName = 'theSequence';   
        Sequence__c soSequence = new Sequence__c(Name = sequenceName);
        insert soSequence;
        Id soSequenceId = soSequence.Id;

        // act 
        SequenceModel sequence = new SequenceModel(soSequence);
        sequence.terminate();
        
        // assemble
        List<Step__c> soSteps = [SELECT Id, Name, Process__r.FullyQualifiedClassName__c, Position__c FROM Step__c WHERE Sequence__c = :soSequenceId];
        Integer actualStepCount  = soSteps.size();
        String actualProcessName;
        Decimal actualPosition; 
        if (soSteps.size() > 0) {
            actualProcessName = soSteps[0].Process__r.FullyQualifiedClassName__c;
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
        //Process__c subscribeProcess = ProcessModel.generateOne(Subscribe.class);
        Process__c terminateProcess = ProcessModel.generateOne(Terminate.class);
        //Process__c subscribeProcess = ProcessModel.generateOne(Subscribe.class);
         
        String sequenceName = 'theSequence';   
        Sequence__c soSequence = new Sequence__c(Name = sequenceName);
        insert soSequence;
        Id soSequenceId = soSequence.Id;

        // act 
        SequenceModel sequence = new SequenceModel(soSequence);
        sequence.terminate(); // once ( terminate will now exist)
        sequence.terminate(); // and again!
        
        // assemble
        List<Step__c> soSteps = [SELECT Id, Name, Process__r.FullyQualifiedClassName__c, Position__c FROM Step__c WHERE Sequence__c = :soSequenceId];
        Integer actualStepCount  = soSteps.size();
        String actualProcessName;
        Decimal actualPosition; 
        if (soSteps.size() > 0) {
            actualProcessName = soSteps[0].Process__r.FullyQualifiedClassName__c;
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
 
    private static testmethod void callingDeleteStepWillNotDeleteStepOnADifferentSequence() {
        // arrange
        Process__c subscribeProcess = ProcessModel.generateOne(Subscribe.class);
        Process__c terminateProcess = ProcessModel.generateOne(Terminate.class);
 
        String sequenceNameA = 'theSequenceA';   
        Sequence__c soSequenceA = new Sequence__c(Name = sequenceNameA);
        insert soSequenceA;
        Id soSequenceAId = soSequenceA.Id;
        Step__c stepA1 = StepModel.generateOne(soSequenceAId, subscribeProcess.Id);
        Step__c stepA2 = StepModel.generateOne(soSequenceAId, terminateProcess.Id);

        String sequenceNameB = 'theSequenceB';   
        Sequence__c soSequenceB = new Sequence__c(Name = sequenceNameB);
        insert soSequenceB;
        Id soSequenceBId = soSequenceB.Id;
        Step__c stepB1 = StepModel.generateOne(soSequenceBId, subscribeProcess.Id);
        Step__c stepB2 = StepModel.generateOne(soSequenceBId, terminateProcess.Id);

        // act 
        Id notStepAId =  stepB1.Id;
        SequenceModel sequenceA = new SequenceModel(soSequenceA);
        Boolean actualFlag = false;
        try {
            StepSetModel actualSteps = sequenceA.destroySteps(new Set<Id>{notStepAId});
        } catch (Exception e) {   
            actualFlag = true;
        }

        // assert
        Boolean expectedFlag  = true;
        System.assertEquals( expectedFlag , actualFlag  ); 
    }    

        private static testmethod void callingDeleteStepWillDeleteStepOnThisSequence() {
        // arrange
        Process__c subscribeProcess = ProcessModel.generateOne(Subscribe.class);
        Process__c terminateProcess = ProcessModel.generateOne(Terminate.class);
 
        String sequenceNameA = 'theSequenceA';   
        Sequence__c soSequenceA = new Sequence__c(Name = sequenceNameA);
        insert soSequenceA;
        Id soSequenceAId = soSequenceA.Id;
        Step__c stepA1 = StepModel.generateOne(soSequenceAId, subscribeProcess.Id);
        Step__c stepA2 = StepModel.generateOne(soSequenceAId, terminateProcess.Id);
 

        // act 
        Id deletedStepId =  stepA1.Id;
        SequenceModel sequenceA = new SequenceModel(soSequenceA);
        StepSetModel actualSteps = sequenceA.destroySteps(new Set<Id>{deletedStepId});
 
        
        // assemble
        List<Step__c> soSteps = [SELECT Id, Name, Process__r.FullyQualifiedClassName__c, Position__c FROM Step__c];
        Integer actualStepsCount  = soSteps.size();
        String actualProcessName;
        Decimal actualPosition; 
        if (soSteps.size() > 0) {
            actualProcessName = soSteps[0].Process__r.FullyQualifiedClassName__c;
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