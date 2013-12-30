@isTest public class PublishTest {

	static testMethod void testDescriptionContainsConfigurationObjectName() {
		//arrange
		Publish publish = new Publish();
		
		//act
		Process.PluginDescribeResult plugin = publish.describe();
		Map<String,Object> meta = Utility.meta(plugin.Description);
		
		//assert
		String expectedConfiguration = Schema.SObjectType.PublishConfiguration__c.Name;
		String actualConfiguration = (String)meta.get('eda__configurable');
		System.assertEquals(expectedConfiguration, actualConfiguration);
	}
	
	static testMethod void testUnconfiguredPublishProcessThrowsException() {
		//arrange
		Process__c process = new Process__c(Name = 'Publish');
		insert process;
		
		Chain__c chain = new Chain__c(Name = 'TestChain');
		insert chain;
		
		ChainStep__c chainStep = new ChainStep__c(Chain__c = chain.Id, Process__c = process.Id, Sequence__c = 1);
		insert chainStep;
		
		Publish publish = new Publish();
		Map<String,Object> notification = new Map<String,Object>{'eda__chainName' => 'TestChain', 'eda__sequence' => 1};
		Process.PluginRequest request = new Process.PluginRequest(notification);
		
		//act
		Boolean thrown = false;
		try {publish.invoke(request);}
		catch (Publish.PublishException e) {thrown = true;}
		
		//assert
		System.assert(thrown);
	}
	
	static testMethod void testNoSubscribersStillReturnsOneNotification() {
		//arrange
		Process__c process = new Process__c(Name = 'Publish');
		insert process;
		
		Event__c event = new Event__c(Name = 'TestEvent');
		insert event;
		
		Chain__c chain = new Chain__c(Name = 'TestChain');
		insert chain;
		
		ChainStep__c chainStep = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 1, Process__c = process.Id);
		insert chainStep;
		
		PublishConfiguration__c publishConfiguration = [SELECT Id FROM PublishConfiguration__c];
		publishConfiguration.Event__c = event.Id;
		update publishConfiguration;
		
		String data = '{"eda__chainName":"TestChain","eda__sequence":1}';
		Map<String,Object> notification = (Map<String,Object>)System.Json.deserializeUntyped(data);
		Publish publish = new Publish();
		
		//act
		Process.PluginResult results = publish.invoke(new Process.PluginRequest(notification));
		List<Map<String,Object>> notifications = Utility.convert(results);
		
		//assert
		Integer expectedSize = 1;
		Integer actualSize = notifications.size();
		System.assertEquals(expectedSize, actualSize);
		
		String expectedData = data;
		String actualData = System.Json.serialize(notifications[0]);
		System.assertEquals(expectedData, actualData);
	}
	
	static testMethod void testSubscribersAffectNotificationsReturned() {
		Event__c event = new Event__c(Name = 'TestEvent');
		insert event;
		
		//publish process
		Process__c publish = new Process__c(Name = 'Publish');
		insert publish;
		
		//publish chains and steps
		Chain__c publisher = new Chain__c(Name = 'Publisher');
		insert publisher;
		
		ChainStep__c publisherStep = new ChainStep__c(Chain__c = publisher.Id, Sequence__c = 1, Process__c = publish.Id);
		insert publisherStep;
		
		publisherStep = [SELECT Id, Configuration__c FROM ChainStep__c WHERE Id = :publisherStep.Id];
		
		Database.update(new PublishConfiguration__c(
			Id = publisherStep.Configuration__c,
			Event__c = event.Id
		));
		
		//subsribe process
		Process__c subscribe = new Process__c(Name = 'Subscribe');
		insert subscribe;
		
		//subscribe chains and steps
		Chain__c subscriber1 = new Chain__c(Name = 'Subscriber1');
		insert subscriber1;
		
		ChainStep__c subscriber1step = new ChainStep__c(Chain__c = subscriber1.Id, Sequence__c = 1, Process__c = subscribe.Id);
		insert subscriber1step;
		
		subscriber1step = [SELECT Id, Configuration__c FROM ChainStep__c WHERE Id = :subscriber1step.Id];
		
		Database.update(new SubscribeConfiguration__c(
			Id = subscriber1step.Configuration__c,
			Event__c = event.Id
		));
		
		Chain__c subscriber2 = new Chain__c(Name = 'Subscriber2');
		insert subscriber2;
		
		ChainStep__c subscriber2step = new ChainStep__c(Chain__c = subscriber2.Id, Sequence__c = 1, Process__c = subscribe.Id);
		insert subscriber2step;
		
		subscriber2step = [SELECT Id, Configuration__c FROM ChainStep__c WHERE Id = :subscriber2step.Id];
		
		Database.update(new SubscribeConfiguration__c(
			Id = subscriber2step.Configuration__c,
			Event__c = event.Id
		));
		
		//arrange
		Map<String,Object> notification = new Map<String,Object>{'eda__chainName' => 'Publisher', 'eda__sequence' => 1};
		
		//act
		Publish process = new Publish();
		Process.PluginResult results = process.invoke(new Process.PluginRequest(notification));
		List<Map<String,Object>> notifications = Utility.convert(results);
		
		//assert
		Integer expectedSize = 3;
		Integer actualSize = notifications.size();
		System.assertEquals(expectedSize, actualSize);
	}
	
}