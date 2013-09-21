@isTest public class ChainStepAfterInsertTest {
	
	//dummy configurable process
	public class MockProcess implements Processable, Configurable {
		
		//which uses some kind of SObject for configuration
		public SObject configure() {
			return new Account(Name = 'Some Object');
		}
		
		public List<Map<String,Object>> execute(Map<String,Object> notification) {
			return new List<Map<String,Object>>{notification};
		}
		
	}
	
	static testMethod void testChainStepConfigurationIsCreatedWhenInserted() {
		//arrange
		Process__c process = new Process__c(ApexClass__c = 'ChainStepAfterInsertTest.MockProcess');
		insert process;
		
		Chain__c chain = new Chain__c(Name = 'TestChain');
		insert chain;
		
		//act
		ChainStep__c chainStep = new ChainStep__c(Chain__c = chain.Id, Process__c = process.Id);
		insert chainStep;
		
		//requery after trigger
		chainStep = [SELECT Id, Configuration__c FROM ChainStep__c WHERE Id = :chainStep.Id];
		
		//assert
		String expectedId = '001'; //some account record
		String actualId = chainStep.Configuration__c;
		System.assert(actualId.startsWith(expectedId));
	}
	
}