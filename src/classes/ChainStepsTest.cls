@isTest private class ChainStepsTest {
    
    //after insert test
    static testMethod void testChainStepConfigurationIsCreatedWhenInserted() {
        //arrange
        String  className  = 'Boomerang';
        List<String> names = new List<String>{className};
        List<ApexClass> objects = [SELECT NamespacePrefix, Name FROM ApexClass WHERE Name IN :Names];
        ApexClasses apexClasses = new ApexClasses(objects);
        List<Process__c> processes = apexClasses.regenerate();
        insert processes;

        Chain__c chain = new Chain__c(Name = 'TestChain');
        insert chain;
        
        //act
        ChainStep__c chainStep = new ChainStep__c(Chain__c = chain.Id, Process__c =  processes[0].Id, Sequence__c = 1);
        insert chainStep;
        
        //requery after trigger
        chainStep = [SELECT Id, ConfigurationId__c FROM ChainStep__c WHERE Id = :chainStep.Id];
        
        //assert
        String expectedId = Schema.SObjectType.BoomerangConfiguration__c.KeyPrefix; //this needs to be some config record
        String actualId = chainStep.ConfigurationId__c;
        System.assert(actualId.startsWith(expectedId));
    }
 
    //after insert test
    static testMethod void testNoResequencingOfStepsWhenAllInsertedStepsHaveASequenceGtZero() {
        //arrange 
        Integer SequenceGtZero1 = 1;
        Integer SequenceGtZero2 = 2;
        Process__c process1 = new Process__c(Name = 'WireTap');
        insert process1;
        Process__c process2 = new Process__c(Name = 'Terminate');
        insert process2;
        
        Chain__c chain = new Chain__c(Name = 'TestChain');
        insert chain;
        
        //act
        ChainStep__c chainStep1 = new ChainStep__c(Chain__c = chain.Id, Sequence__c = SequenceGtZero1, Process__c = process1.Id);
        ChainStep__c chainStep2 = new ChainStep__c(Chain__c = chain.Id, Sequence__c = SequenceGtZero2, Process__c = process2.Id);
        insert new List<ChainStep__c> {chainStep1, chainStep2};
        
        //assemble : requery after trigger
        List<ChainStep__c> chainSteps = [SELECT Id, Chain__c, Sequence__c FROM ChainStep__c WHERE Chain__c = :chain.Id];
        Integer actualSequence1 = -1;
        Integer actualSequence2 = -1;
        Integer offset = 1;
        for (ChainStep__c chainStep : chainSteps ) {
            if (offset == 1) actualSequence1 = (Integer) chainStep.Sequence__c;
            if (offset == 2) actualSequence2 = (Integer) chainStep.Sequence__c;
            offset++;
        }
        
        //assert
        Integer expectedSize = 2;
        Integer actualSize = chainSteps.size(); 
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
        
        Process__c process1 = new Process__c(Name = 'WireTap');
        insert process1;
        Process__c process2 = new Process__c(Name = 'Terminate');
        insert process2;
     
        
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
        
        ChainStep__c chainStep1 = new ChainStep__c(Chain__c = chain.Id, Sequence__c = SequenceGtZero1, Process__c = process1.Id);
        ChainStep__c chainStep2 = new ChainStep__c(Chain__c = chain.Id, Sequence__c = SequenceGtZero2, Process__c = process2.Id);
        ChainStep__c chainStep3 = new ChainStep__c(Chain__c = chain.Id, Sequence__c = SequenceEqToZero3, Process__c = process1.Id);
        ChainStep__c chainStep4 = new ChainStep__c(Chain__c = chain.Id, Sequence__c = SequenceEqToZero4, Process__c = process1.Id);
        insert chainStep1;
        insert chainStep2;
        insert chainStep3;
        insert chainStep4;
        
            
        //asemble : requery after trigger
        List<ChainStep__c> chainSteps = [SELECT Id, Chain__c, Sequence__c
                                         FROM ChainStep__c
                                         WHERE Chain__c = :chain.Id 
                                         ORDER BY Id 
                                        ];
        Integer actualSequence1 = -1;
        Integer actualSequence2 = -1;
        Integer actualSequence3 = -1;
        Integer actualSequence4 = -1;
        Integer offset = 1;
        for (ChainStep__c chainStep : chainSteps ) {
            if (offset == 1) actualSequence1 = (Integer) chainStep.Sequence__c;
            if (offset == 2) actualSequence2 = (Integer) chainStep.Sequence__c;
            if (offset == 3) actualSequence3 = (Integer) chainStep.Sequence__c;
            if (offset == 4) actualSequence4 = (Integer) chainStep.Sequence__c;
            offset++;
        }
    
        
        //assert
        Integer expectedSize = 4;
        Integer actualSize = chainSteps.size(); 
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
    static testMethod void firingChainStepBeforeDeleteDeletesConfig() {
        // Arrange :
        String  chainName = 'the-chain';
        String  apexClass = 'Branch';
        Decimal sequence  = 1;
        String  data      = 'data';
        
        Chain__c chain = new Chain__c(Name = chainName);
        insert chain;
        
    
        List<String> names = new List<String>{apexClass};
        List<ApexClass> objects = [SELECT NamespacePrefix, Name FROM ApexClass WHERE Name IN :Names];
        ApexClasses apexClasses = new ApexClasses(objects);
        List<Process__c> processes = apexClasses.regenerate();
        insert processes;
        Map<string,Process__c> procecessNameToProcess = new Map<string,Process__c>();
        for (Process__c p : processes) {
           procecessNameToProcess.put(p.Name, p); 
        }
        Process__c process =  (Process__c )procecessNameToProcess.get(apexClass);
        
        
        ChainStep__c chainStep = new ChainStep__c(
            Chain__c    = chain.Id ,
            Process__c  = process.Id,
            Sequence__c = sequence
        );
        insert chainStep;
        
        integer expectedSizeBefore =  1;
        integer expectedSizeAfter =   0;
        
        integer actualSizeBefore = [SELECT Id FROM BranchConfiguration__c].size();
        
        //Act
        delete chainStep;
        
        //Prepare
        integer actualSizeAfter =  [SELECT id FROM BranchConfiguration__c].size();
        
        //Assert
        System.assertEquals(expectedSizeBefore, actualSizeBefore);
        System.assertEquals(expectedSizeAfter, actualSizeAfter);
    }

}