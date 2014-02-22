@isTest private class StepsTest {
    
    //before insert test
    static testMethod void testStepConfigurationIsCreatedWhenInserted() {
        //arrange processes
        Process__c boomerangProcess = Processes.generateOne(Boomerang.class);
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        
        //arrange chain
        Chain__c chain = new Chain__c(Name = 'TestChain');
        insert chain;
        
        //arrange steps
        Step__c boomerangStep = Steps.generateOne(chain.Id, boomerangProcess.Id);
        Step__c terminateStep = Steps.generateOne(chain.Id, terminateProcess.Id);
        
        //assert
        String expectedId = Schema.SObjectType.BoomerangConfiguration__c.KeyPrefix; //this needs to be some config record
        String actualId = boomerangStep.ConfigurationId__c;
        System.assert(actualId.startsWith(expectedId));
    }

    //after insert test
    static testMethod void testNoResequencingOfStepsWhenAllInsertedStepsHaveASequenceGtZero() {
        //arrange processes
        Process__c wiretapProcess = Processes.generateOne(Wiretap.class);
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        
        //arrange chain
        Chain__c chain = new Chain__c(Name = 'TestChain');
        insert chain;
        
        //arrange steps
        Integer SequenceGtZero1 = 1;
        Integer SequenceGtZero2 = 2;
        Step__c step1 = new Step__c(Chain__c = chain.Id, Sequence__c = SequenceGtZero1, Process__c = wiretapProcess.Id);
        Step__c step2 = new Step__c(Chain__c = chain.Id, Sequence__c = SequenceGtZero2, Process__c = terminateProcess.Id);
        
        //act
        insert new List<Step__c> {step1, step2};
        
        //assemble : requery after trigger
        List<Step__c> steps = [SELECT Id, Chain__c, Sequence__c FROM Step__c WHERE Chain__c = :chain.Id];
        Integer actualSequence1 = -1;
        Integer actualSequence2 = -1;
        Integer offset = 1;
        for (Step__c step : steps ) {
            if (offset == 1) actualSequence1 = (Integer) step.Sequence__c;
            if (offset == 2) actualSequence2 = (Integer) step.Sequence__c;
            offset++;
        }
        
        //assert
        Integer expectedSize = 2;
        Integer actualSize = Steps.size();
        System.assertEquals(expectedSize, actualSize);
        
        Integer expectedSequence1 = SequenceGtZero1;
        System.assertEquals(expectedSequence1, actualSequence1);
        Integer expectedSequence2 = SequenceGtZero2;
        System.assertEquals(expectedSequence2, actualSequence2);
    }
    
    //after insert test
    static testMethod void testResequencingOfStepsWhenOneOrMoreInsertedStepsHaveSequenceEqToZero() {
        //arrange
        Integer SequenceGtZero1 = 1;
        Integer SequenceGtZero2 = 2;
        Integer SequenceEqToZero3 = 0;
        Integer SequenceEqToZero4 = 0;
        
        //arrange processes
        Process__c wiretapProcess = Processes.generateOne(Wiretap.class);
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        
        //arrange chain
        Chain__c chain = new Chain__c(Name = 'TestChain');
        insert chain;
        
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
        
        Step__c step1 = new Step__c(Chain__c = chain.Id, Sequence__c = SequenceGtZero1, Process__c = wiretapProcess.Id);
        Step__c step2 = new Step__c(Chain__c = chain.Id, Sequence__c = SequenceGtZero2, Process__c = terminateProcess.Id);
        Step__c step3 = new Step__c(Chain__c = chain.Id, Sequence__c = SequenceEqToZero3, Process__c = wiretapProcess.Id);
        Step__c step4 = new Step__c(Chain__c = chain.Id, Sequence__c = SequenceEqToZero4, Process__c = wiretapProcess.Id);
        insert step1;
        insert step2;
        insert step3;
        insert step4;
        
            
        //asemble : requery after trigger
        List<Step__c> steps = [
            SELECT Id, Chain__c, Sequence__c
            FROM Step__c
            WHERE Chain__c = :chain.Id
            ORDER BY Id
        ];
        Integer actualSequence1 = -1;
        Integer actualSequence2 = -1;
        Integer actualSequence3 = -1;
        Integer actualSequence4 = -1;
        Integer offset = 1;
        for (Step__c step : steps ) {
            if (offset == 1) actualSequence1 = (Integer) step.Sequence__c;
            if (offset == 2) actualSequence2 = (Integer) step.Sequence__c;
            if (offset == 3) actualSequence3 = (Integer) step.Sequence__c;
            if (offset == 4) actualSequence4 = (Integer) step.Sequence__c;
            offset++;
        }
    
        
        //assert
        Integer expectedSize = 4;
        Integer actualSize = Steps.size();
        System.assertEquals(expectedSize, actualSize);
        
        Integer expectedSequence1 = SequenceGtZero1; // unaffected
        System.assertEquals(expectedSequence1, actualSequence1);
        Integer expectedSequence2 = SequenceGtZero2; // unaffected
        System.assertEquals(expectedSequence2, actualSequence2);
        Integer expectedSequence3 = 3; // resequence , max+1
        System.assertEquals(expectedSequence3, actualSequence3);
        Integer expectedSequence4 = 4; // resequence , max+1+1
        System.assertEquals(expectedSequence4, actualSequence4);
    }
    
    //before delete test
    static testMethod void firingStepBeforeDeleteDeletesConfig() {
        // Arrange :
        Decimal sequence  = 1;
        String  data      = 'data';
        
        //arrange processes
        Process__c branchProcess = Processes.generateOne(Branch.class);
        
        //arrange chain
        Chain__c chain = new Chain__c(Name = 'the-chain');
        insert chain;
        
        //arrange steps
        Step__c branchStep = Steps.generateOne(chain.Id, branchProcess.Id);
        
        integer expectedSizeBefore =  1;
        integer expectedSizeAfter =   0;
        integer actualSizeBefore = [SELECT Id FROM BranchConfiguration__c].size();
        
        //Act
        delete branchStep;
        
        //Prepare
        integer actualSizeAfter =  [SELECT id FROM BranchConfiguration__c].size();
        
        //Assert
        System.assertEquals(expectedSizeBefore, actualSizeBefore);
        System.assertEquals(expectedSizeAfter, actualSizeAfter);
    }

}