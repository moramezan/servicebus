@isTest  //-- no view of org data
private  class ChainStepBeforeDeleteTest {
    
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