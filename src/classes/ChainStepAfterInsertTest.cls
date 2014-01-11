@isTest public class ChainStepAfterInsertTest {
    
    //dummy configurable process
    public class MockProcess implements Process.Plugin {
        
        //this needs SOME, ANY SObject for configuration that can be inserted with NO required fields
        public Process.PluginDescribeResult describe() {
            Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
            plugin.Description = '{"eda__configurable":"' + Schema.SObjectType.BoomerangConfiguration__c.Name + '"}';
            return plugin;
        }
        
        public Process.PluginResult invoke(Process.PluginRequest request) {
            Map<String,Object> notification = request.inputParameters;
            return Utility.convert(new List<Map<String,Object>>{notification});
        }
        
    }
    
    static testMethod void testChainStepConfigurationIsCreatedWhenInserted() {
        //arrange
        Process__c process = new Process__c(Name = 'ChainStepAfterInsertTest.MockProcess');
        insert process;
        
        Chain__c chain = new Chain__c(Name = 'TestChain');
        insert chain;
        
        //act
        ChainStep__c chainStep = new ChainStep__c(Chain__c = chain.Id, Process__c = process.Id);
        insert chainStep;
        
        //requery after trigger
        chainStep = [SELECT Id, Configuration__c FROM ChainStep__c WHERE Id = :chainStep.Id];
        
        //assert
        String expectedId = Schema.SObjectType.BoomerangConfiguration__c.KeyPrefix; //this needs to be some config record
        String actualId = chainStep.Configuration__c;
        System.assert(actualId.startsWith(expectedId));
    }
 
    static testMethod void testNoResequencingOfStepsWhenAllInsertedStepsHaveASequenceGtZero() {
        //arrange 
        Integer SequenceGtZero1 = 1;
        Integer SequenceGtZero2 = 2;
        Process__c process1 = new Process__c(Name = 'WireTap');
        insert process1;
        Process__c process2 = new Process__c(Name = 'Sink');
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
    
    static testMethod void testResequencingOfStepsWhenOneOrMoreInsertedStepsHaveSequenceEqToZero() {
        //arrange 
        Integer SequenceGtZero1 = 1;
        Integer SequenceGtZero2 = 2; 
        Integer SequenceEqToZero3 = 0;
        Integer SequenceEqToZero4 = 0;
        
        Process__c process1 = new Process__c(Name = 'WireTap');
        insert process1;
        Process__c process2 = new Process__c(Name = 'Sink');
        insert process2;
     
        
        Chain__c chain = new Chain__c(Name = 'TestChain');
        insert chain;
        
        //act
        //pre condition :
        //WireTap 1
        //Sink    2
        //WireTap 0
        //WireTap 0

        //post condition :
        //WireTap 1
        //Sink    2
        //WireTap 3
        //WireTap 4
        
        ChainStep__c chainStep1 = new ChainStep__c(Chain__c = chain.Id, Sequence__c = SequenceGtZero1, Process__c = process1.Id);
        ChainStep__c chainStep2 = new ChainStep__c(Chain__c = chain.Id, Sequence__c = SequenceGtZero2, Process__c = process2.Id);
        ChainStep__c chainStep3 = new ChainStep__c(Chain__c = chain.Id, Sequence__c = SequenceEqToZero3, Process__c = process1.Id);
        ChainStep__c chainStep4 = new ChainStep__c(Chain__c = chain.Id, Sequence__c = SequenceEqToZero4, Process__c = process1.Id);
        insert new List<ChainStep__c> {chainStep1, chainStep2, chainStep3, chainStep4};
            
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
}