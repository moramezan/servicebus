@IsTest private class StepObjectSetTest {
    
    //before insert test
    static testmethod void testStepConfigIsCreatedWhenInserted() {
        //arrange processes
        Process__c subsequenceProcess = ProcessObject.generateOne(Subsequence.class);
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange steps
        Step__c subsequenceStep = StepObject.generateOne(sequence.Id, subsequenceProcess.Id);
        Step__c terminateStep = StepObject.generateOne(sequence.Id, terminateProcess.Id);
        
        //assert
        String expectedId = Schema.SObjectType.SubsequenceConfig__c.KeyPrefix; //this needs to be some config record
        String actualId = subsequenceStep.ConfigId__c;
        System.assert(actualId.startsWith(expectedId));
    }

    //after insert test
    static testmethod void testNoResequencingOfStepsWhenAllInsertedStepsHaveAPositionGtZero() {
        //arrange processes
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange steps
        Integer PositionGtZero1 = 1;
        Integer PositionGtZero2 = 2;
        Step__c step1 = new Step__c(Sequence__c = sequence.Id, Position__c = PositionGtZero1, Process__c = wiretapProcess.Id);
        Step__c step2 = new Step__c(Sequence__c = sequence.Id, Position__c = PositionGtZero2, Process__c = terminateProcess.Id);
        
        //act
        insert new List<Step__c> {step1, step2};
        
        //assemble : requery after trigger
        List<Step__c> steps = [SELECT Id, Sequence__c, Position__c FROM Step__c WHERE Sequence__c = :sequence.Id];
        Integer actualPosition1 = -1;
        Integer actualPosition2 = -1;
        Integer offset = 1;
        for (Step__c step : steps ) {
            if (offset == 1) actualPosition1 = (Integer) step.Position__c;
            if (offset == 2) actualPosition2 = (Integer) step.Position__c;
            offset++;
        }
        
        //assert
        Integer expectedSize = 2;
        Integer actualSize = Steps.size();
        System.assertEquals(expectedSize, actualSize);
        
        Integer expectedPosition1 = PositionGtZero1;
        System.assertEquals(expectedPosition1, actualPosition1);
        Integer expectedPosition2 = PositionGtZero2;
        System.assertEquals(expectedPosition2, actualPosition2);
    }
    
    //after insert test
    static testmethod void testResequencingOfStepsWhenOneOrMoreInsertedStepsHavePositionEqToZero() {
        //arrange
        Integer PositionGtZero1 = 1;
        Integer PositionGtZero2 = 2;
        Integer PositionEqToZero3 = 0;
        Integer PositionEqToZero4 = 0;
        
        //arrange processes
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //act
        //pre condition :
        //WireTap   1
        //Terminate 2
        //WireTap   0
        //WireTap   0

        //post condition :
        //WireTap   1
        //Terminate 2
        //WireTap   3
        //WireTap   4
        
        Step__c step1 = new Step__c(Sequence__c = sequence.Id, Position__c = PositionGtZero1, Process__c = wiretapProcess.Id);
        Step__c step2 = new Step__c(Sequence__c = sequence.Id, Position__c = PositionGtZero2, Process__c = terminateProcess.Id);
        Step__c step3 = new Step__c(Sequence__c = sequence.Id, Position__c = PositionEqToZero3, Process__c = wiretapProcess.Id);
        Step__c step4 = new Step__c(Sequence__c = sequence.Id, Position__c = PositionEqToZero4, Process__c = wiretapProcess.Id);
        insert step1;
        insert step2;
        insert step3;
        insert step4;
        
            
        //asemble : requery after trigger
        List<Step__c> steps = [
            SELECT Id, Sequence__c, Position__c
            FROM Step__c
            WHERE Sequence__c = :sequence.Id
            ORDER BY Id
        ];
        Integer actualPosition1 = -1;
        Integer actualPosition2 = -1;
        Integer actualPosition3 = -1;
        Integer actualPosition4 = -1;
        Integer offset = 1;
        for (Step__c step : steps ) {
            if (offset == 1) actualPosition1 = (Integer) step.Position__c;
            if (offset == 2) actualPosition2 = (Integer) step.Position__c;
            if (offset == 3) actualPosition3 = (Integer) step.Position__c;
            if (offset == 4) actualPosition4 = (Integer) step.Position__c;
            offset++;
        }
    
        
        //assert
        Integer expectedSize = 4;
        Integer actualSize = Steps.size();
        System.assertEquals(expectedSize, actualSize);
        
        Integer expectedPosition1 = PositionGtZero1; // unaffected
        System.assertEquals(expectedPosition1, actualPosition1);
        Integer expectedPosition2 = PositionGtZero2; // unaffected
        System.assertEquals(expectedPosition2, actualPosition2);
        Integer expectedPosition3 = 3; // reposition , max+1
        System.assertEquals(expectedPosition3, actualPosition3);
        Integer expectedPosition4 = 4; // reposition , max+1+1
        System.assertEquals(expectedPosition4, actualPosition4);
    }
    
    //before delete test
    static testmethod void firingStepBeforeDeleteDeletesConfig() {
        // Arrange :
        Decimal position  = 1;
        String  data      = 'data';
        
        //arrange processes
        Process__c branchProcess = ProcessObject.generateOne(Branch.class);
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'the-sequence');
        insert sequence;
        
        //arrange steps
        Step__c branchStep = StepObject.generateOne(sequence.Id, branchProcess.Id);
        
        Integer expectedSizeBefore =  1;
        Integer expectedSizeAfter =   0;
        Integer actualSizeBefore = [SELECT COUNT() FROM BranchConfig__c];
        
        //Act
        delete branchStep;
        
        //Prepare
        Integer actualSizeAfter = [SELECT COUNT() FROM BranchConfig__c];
        
        //Assert
        System.assertEquals(expectedSizeBefore, actualSizeBefore);
        System.assertEquals(expectedSizeAfter, actualSizeAfter);
    }

}