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
	
}