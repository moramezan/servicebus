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
		
		Process__c process = new Process__c(ApexClass__c = apexClass);
		insert process;
		
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