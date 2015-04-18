@IsTest private class StepSetModelTest {
    
    //after insert test
    static testmethod void testNoResequencingOfStepsWhenAllInsertedStepsHaveAPositionGtZero() {
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange steps
        Integer PositionGtZero1 = 1;
        Integer PositionGtZero2 = 2;
        
        //act
        Step__c step1 = StepModel.generateOne(sequence.Name, Wiretap.class.getName());
        Step__c step2 = StepModel.generateOne(sequence.Name, Terminate.class.getName());
        
        //assemble : requery after trigger
        List<Step__c> steps = [SELECT Id, SequenceName__c, Position__c FROM Step__c WHERE SequenceName__c = :sequence.Name];
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
        
        Step__c step1 = StepModel.generateOne(sequence.Name, Wiretap.class.getName());
        Step__c step2 = StepModel.generateOne(sequence.Name, Terminate.class.getName());
        Step__c step3 = StepModel.generateOne(sequence.Name, Wiretap.class.getName());
        Step__c step4 = StepModel.generateOne(sequence.Name, Wiretap.class.getName());
        
            
        //asemble : requery after trigger
        List<Step__c> steps = [
            SELECT Id, SequenceName__c, Position__c
            FROM Step__c
            WHERE SequenceName__c = :sequence.Name
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
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'the-sequence');
        insert sequence;
        
        //arrange steps
        Step__c branchStep = StepModel.generateOne(sequence.Name, Branch.class.getName());
        
        Integer expectedSizeBefore =  1;
        Integer expectedSizeAfter =   0;
        Integer actualSizeBefore = [SELECT COUNT() FROM BranchConfig__c];
        
        //Act
        SequenceModel.fromName('the-sequence').destroySteps(new Set<Id>{branchStep.Id});
        
        //Prepare
        Integer actualSizeAfter = [SELECT COUNT() FROM BranchConfig__c];
        
        //Assert
        System.assertEquals(expectedSizeBefore, actualSizeBefore);
        System.assertEquals(expectedSizeAfter, actualSizeAfter);
    }

}