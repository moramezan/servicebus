@isTest private class ChainsTest {

    //before delete
    static testMethod void testDeletesAreCascaded() {
        //arrange process
        Process__c process = new Process__c(Name = 'Terminate');
        insert process;
        
        //arrange chain
        Chain__c chain = new Chain__c(Name = 'testChain');
        insert chain;
        
        //arrange steps
        ChainStep__c step1 = new ChainStep__c(Chain__c = chain.Id, Process__c = process.Id);
        ChainStep__c step2 = new ChainStep__c(Chain__c = chain.Id, Process__c = process.Id);
        ChainStep__c step3 = new ChainStep__c(Chain__c = chain.Id, Process__c = process.Id);
        insert step1;
        insert step2;
        insert step3;
        
        //act
        delete chain;
        
        //arrange
        List<ChainStep__c> steps = [SELECT Id FROM ChainStep__c];
        
        //assert
        System.assert(steps.isEmpty());
    }

}