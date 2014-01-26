@isTest private class ChainsTest {

    //before delete
    static testMethod void testDeleteTriggersAreCascaded() {
        //arrange process
        Process__c branchProcess = Processes.generateOne(Branch.class);
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        
        //arrange chain
        Chain__c chain = new Chain__c(Name = 'testChain');
        insert chain;
        
        //arrange steps
        ChainStep__c branchStep = ChainSteps.generateOne(chain.Id, branchProcess.Id);
        ChainStep__c terminateStep = ChainSteps.generateOne(chain.Id, terminateProcess.Id);
        
        Integer expectedConfigsBefore = 1;
        Integer actualConfigsBefore = [SELECT COUNT() FROM BranchConfiguration__c];
        
        //act
        delete chain;
        
        Integer expectedConfigsAfter = 0;
        Integer actualConfigsAfter = [SELECT COUNT() FROM BranchConfiguration__c];
        
        //assert
        System.assertEquals(expectedConfigsBefore, actualConfigsBefore);
        System.assertEquals(expectedConfigsAfter, actualConfigsAfter);
    }

}