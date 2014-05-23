@isTest
private class  SequenceTest {
            
    private static testMethod void  callingFetchStepsReturnsExpectedStepCollection() {
        // arrange
        Process__c markProcess = ProcessSet.generateOne(Mark.class);
        Process__c terminateProcess = ProcessSet.generateOne(Terminate.class);
        Process__c subscribeProcess = ProcessSet.generateOne(Subscribe.class);
         
        String sequenceName = 'theSequence';   
        Sequence__c soSequence = new Sequence__c(Name = sequenceName);
        insert soSequence;
        Id soSequenceId = soSequence.Id;

        Step__c stepA1 = StepObjectSet.generateOne(soSequenceId, subscribeProcess.Id);
        Step__c stepA2 = StepObjectSet.generateOne(soSequenceId, markProcess.Id);
        Step__c stepA3 = StepObjectSet.generateOne(soSequenceId, terminateProcess.Id);
        Decimal positionA1 = stepA1.Position__c;
        Decimal positionA2 = stepA2.Position__c;
        Decimal positionA3 = stepA3.Position__c;

        // act 
        Sequence sequence = new Sequence(soSequence);
        StepObjectSet actualSteps  = sequence.fetchSteps();
        
        // assemble
        List<Step__c> soSteps = actualSteps.getSObjects();
        Integer actualStepCount = soSteps.size();

        // assert
        
        Integer expectedStepCount = 3;
        System.assertEquals( expectedStepCount , actualStepCount  );
    }
    
    private static testMethod void callingAppendStepAddStepWithExpectedProcessInExpectedPosition() {
        // arrange
        Process__c markProcess = ProcessSet.generateOne(Mark.class);

        String sequenceName = 'theSequence';   
        Sequence__c soSequence = new Sequence__c(Name = sequenceName);
        insert soSequence;
        Id soSequenceId = soSequence.Id;

        // act 
        Sequence sequence = new Sequence(soSequence);
        StepObject actualStep = sequence.appendStep(markProcess.Id);
        
        // assemble
        List<Step__c> soSteps = [SELECT Id, Name, Process__r.FullyQualifiedClassName__c, Position__c FROM Step__c WHERE Sequence__c = :soSequenceId];
        Integer actualStepCount  = soSteps.size();
        // SObject soStep = actualStep.getSObject();
        String actualProcessName;
        Decimal actualPosition; 
        if (soSteps.size() > 0) {
            actualProcessName = soSteps[0].Process__r.FullyQualifiedClassName__c;
            actualPosition = soSteps[0].Position__c;
        }
        
        // assert
        Decimal expectedPosition = 1;
        System.assertEquals( expectedPosition , actualPosition  );
        String expectedProcessName = Mark.class.getName();
        System.assertEquals( expectedProcessName , actualProcessName  );
        Integer expectedStepCount = 1;
        System.assertEquals( expectedStepCount , actualStepCount  );  
    } 

   	private static testMethod void callingTerminateAddsTerminateStepIfNoTerminateStepExists() {
        // arrange
        Process__c terminateProcess = ProcessSet.generateOne(Terminate.class);

        String sequenceName = 'theSequence';   
        Sequence__c soSequence = new Sequence__c(Name = sequenceName);
        insert soSequence;
        Id soSequenceId = soSequence.Id;

        // act 
        Sequence sequence = new Sequence(soSequence);
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
    
    private static testMethod void callingTerminateDoesNotAddTerminateStepIfTerminateStepExists() {
        // arrange
        //Process__c markProcess = ProcessSet.generateOne(Mark.class);
        Process__c terminateProcess = ProcessSet.generateOne(Terminate.class);
        //Process__c subscribeProcess = ProcessSet.generateOne(Subscribe.class);
         
        String sequenceName = 'theSequence';   
        Sequence__c soSequence = new Sequence__c(Name = sequenceName);
        insert soSequence;
        Id soSequenceId = soSequence.Id;

        // act 
        Sequence sequence = new Sequence(soSequence);
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
 
    private static testMethod void callingDeleteStepWillNotDeleteStepOnADifferentSequence() {
        // arrange
        Process__c markProcess = ProcessSet.generateOne(Mark.class);
        Process__c terminateProcess = ProcessSet.generateOne(Terminate.class);
 
        String sequenceNameA = 'theSequenceA';   
        Sequence__c soSequenceA = new Sequence__c(Name = sequenceNameA);
        insert soSequenceA;
        Id soSequenceAId = soSequenceA.Id;
        Step__c stepA1 = StepObjectSet.generateOne(soSequenceAId, markProcess.Id);
        Step__c stepA2 = StepObjectSet.generateOne(soSequenceAId, terminateProcess.Id);

        String sequenceNameB = 'theSequenceB';   
        Sequence__c soSequenceB = new Sequence__c(Name = sequenceNameB);
        insert soSequenceB;
        Id soSequenceBId = soSequenceB.Id;
        Step__c stepB1 = StepObjectSet.generateOne(soSequenceBId, markProcess.Id);
        Step__c stepB2 = StepObjectSet.generateOne(soSequenceBId, terminateProcess.Id);

        // act 
        Id notStepAId =  stepB1.Id;
        Sequence sequenceA = new Sequence(soSequenceA);
        Boolean actualFlag = false;
        try {
            StepObjectSet actualSteps = sequenceA.destroySteps(new Set<Id>{notStepAId});
        } catch (Exception e) {   
            actualFlag = true;
        }

        // assert
        Boolean expectedFlag  = true;
        System.assertEquals( expectedFlag , actualFlag  ); 
    }    

        private static testMethod void callingDeleteStepWillDeleteStepOnThisSequence() {
        // arrange
        Process__c markProcess = ProcessSet.generateOne(Mark.class);
        Process__c terminateProcess = ProcessSet.generateOne(Terminate.class);
 
        String sequenceNameA = 'theSequenceA';   
        Sequence__c soSequenceA = new Sequence__c(Name = sequenceNameA);
        insert soSequenceA;
        Id soSequenceAId = soSequenceA.Id;
        Step__c stepA1 = StepObjectSet.generateOne(soSequenceAId, markProcess.Id);
        Step__c stepA2 = StepObjectSet.generateOne(soSequenceAId, terminateProcess.Id);
 

        // act 
        Id deletedStepId =  stepA1.Id;
        Sequence sequenceA = new Sequence(soSequenceA);
        StepObjectSet actualSteps = sequenceA.destroySteps(new Set<Id>{deletedStepId});
 
        
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