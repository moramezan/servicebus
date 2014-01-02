@isTest public class BranchTest {
	
	static testMethod void testConfigureReturnsRightObjectType() {
		//new up the process and interrogate its description
		Branch process = new Branch();
		Process.PluginDescribeResult plugin = process.describe();
		
		//get metadata from description and instantiate a configuration record
		Map<String,Object> meta = Utility.meta(plugin.Description);
		Type reflector = Type.forName((String)meta.get('eda__configurable'));
		SObject config = (SObject)reflector.newInstance();
		
		//compare instance types
		String expectedType = Schema.SObjectType.BranchConfiguration__c.Name;
		String actualType = config.getSObjectType().getDescribe().getName();
		System.assertEquals(expectedType, actualType);
	}
	
	static testMethod void testTwoNotificationsReturned() {
		//arrange chains
		Chain__c origin = new Chain__c(Name = 'originChain');
		Chain__c target = new Chain__c(Name = 'targetChain');
		insert origin;
		insert target;
		
		//arrange config
		BranchConfiguration__c config = new BranchConfiguration__c(Chain__c = target.Id);
		insert config;
		
		//arrange notification
		Map<String,Object> notification = new Map<String,Object>{
			'eda__chainName' => origin.Name,
			'eda__sequence' => 1,
			'eda__configuration' => config.Id
		};
		
		//arrange processable
		Branch process = new Branch();
		
		//act
		Process.PluginResult result = process.invoke(new Process.PluginRequest(notification));
		List<Map<String,Object>> notifications = Utility.convert(result);
		
		//assert
		Decimal expectedSize = 2;
		Decimal actualSize = notifications.size();
		System.assertEquals(expectedSize, actualSize);
		
		//act
		Map<String,Object> normalNotification = notifications[0]; //the normal notifications continues to the next step
		
		//asserts
		String expectedNormalChainName = origin.Name;
		String actualNormalChainName = (String)normalNotification.get('eda__chainName');
		System.assertEquals(expectedNormalChainName, actualNormalChainName);
		
		Decimal expectedNormalSequence = 1;
		Decimal expectedActualSequence = (Decimal)normalNotification.get('eda__sequence');
		System.assertEquals(expectedNormalSequence, expectedActualSequence);
		
		//act
		Map<String,Object> branchNotification = notifications[1]; //the branch notification goes to the top of another chain
		
		//asserts
		String expectedBranchChainName = target.Name;
		String actualBranchChainName = (String)branchNotification.get('eda__chainName');
		System.assertEquals(expectedBranchChainName, actualBranchChainName);
		
		Decimal expectedBranchSequence = 0;
		Decimal actualBranchSequence = (Decimal)branchNotification.get('eda__sequence');
		System.assertEquals(expectedBranchSequence, actualBranchSequence);
	}
	
	static testMethod void testInfiniteLoopFuckupGetsCaught() {
		//arrange chains
		Chain__c chain = new Chain__c(Name = 'originChain');
		insert chain;
		
		//arrange config
		BranchConfiguration__c config = new BranchConfiguration__c(Chain__c = chain.Id);
		insert config;
		
		//arrange notification
		Map<String,Object> notification = new Map<String,Object>{
			'eda__chainName' => chain.Name,
			'eda__sequence' => 1,
			'eda__configuration' => config.Id
		};
		
		//arrange process
		Branch process = new Branch();
		
		//arrange exception
		Boolean exceptionThrown = false;
		
		//act
		try {
			Process.PluginResult result = process.invoke(new Process.PluginRequest(notification));
			List<Map<String,Object>> notifications = Utility.convert(result);
		} catch (Exception e) {
			exceptionThrown = true;
			System.assert(e instanceof Branch.BranchException);
		}
		
		//assert
		System.assert(exceptionThrown);
	}

}