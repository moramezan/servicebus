@isTest public class BoomerangTest {
	
	static testMethod void testConfigurationReturnsObject() {
		Boomerang process = new Boomerang();
		SObject config = (SObject)process.configure();
		
		String expectedType = SObjectType.BoomerangConfiguration__c.Name;
		String actualType = String.valueOf(config);
		System.assert(actualType.startsWith(expectedType));
	}
	
	static testMethod void testNotificationIsRedirected() {
		//prepare chains in db
		Chain__c origin = new Chain__c(Name = 'originChain');
		Chain__c target = new Chain__c(Name = 'targetChain');
		insert origin;
		insert target;
		
		//prepare configuration in db
		BoomerangConfiguration__c config = new BoomerangConfiguration__c(Chain__c = target.Id);
		insert config;
		
		//prepare notification
		Map<String,Object> notification = new Map<String,Object>{
			'chainName' => 'originChain',
			'sequence' => 0,
			'configuration' => config.Id
		};
		
		//act
		Boomerang process = new Boomerang();
		List<Map<String,Object>> notifications = process.execute(notification);
		
		//asserts
		Decimal expectedSize = 1;
		Decimal actualSize = notifications.size();
		System.assertEquals(expectedSize, actualSize);
		
		String expectedChainName = 'targetChain';
		String actualChainName = (String)notifications[0].get('chainName');
		System.assertEquals(expectedChainName, actualChainName);
		
		Decimal expectedSequence = 0;
		Decimal actualSequence = (Decimal)notifications[0].get('sequence');
		System.assertEquals(expectedSequence, actualSequence);
	}
	
}