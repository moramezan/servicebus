@isTest public class BrokerTest {

	//count batch invocations
	static Integer executions = 0;
	
	//mock process
	public class Noop implements Process.Plugin {
		public Process.PluginDescribeResult describe() {
			return new Process.PluginDescribeResult();
		}
		
		public Process.PluginResult invoke(Process.PluginRequest request) {
			Map<String,Object> notification = request.inputParameters;
			BrokerTest.executions++;
			return Utility.convert(new List<Map<String,Object>>{notification});
		}
	}
	
	static testMethod void testNotificationProgressesThroughChain() {
		//arrange processes
		Process__c noopProcess = new Process__c(Name = 'BrokerTest.Noop');
		Process__c sinkProcess = new Process__c(Name = 'Sink');
		insert noopProcess;
		insert sinkProcess;
		
		//arrange chain
		Chain__c chain = new Chain__c(Name = 'testChain');
		insert chain;
		
		//arrange steps
		ChainStep__c step1 = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 1, Process__c = noopProcess.Id);
		ChainStep__c step2 = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 2, Process__c = noopProcess.Id);
		ChainStep__c step3 = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 3, Process__c = sinkProcess.Id);
		insert step1;
		insert step2;
		insert step3;
		
		//arrange notification
		Map<String,Object> notification = new Map<String,Object>{
			'eda__chainName' => chain.Name,
			'eda__sequence' => 0
		};
		
		//arrange persistent data
		PersistentData__c data = new PersistentData__c(
			Notification__c = Json.serialize(notification),
			RecordTypeId = SObjectType.PersistentData__c.RecordTypeInfosByName.get('Buffer').RecordTypeId
		);
		insert data;
		
		//act
		Test.startTest();
		Broker broker = new Broker();
		Database.executeBatch(broker, 1);
		Test.stopTest();
		
		Integer expectedExecutions = 2;
		Integer actualExecutions = BrokerTest.executions;
		System.assertEquals(expectedExecutions, actualExecutions);
	}
	
	static testMethod void testEnqueueByBlob() {
		//arrange processes
		Process__c noopProcess = new Process__c(Name = 'BrokerTest.Noop');
		Process__c sinkProcess = new Process__c(Name = 'Sink');
		insert noopProcess;
		insert sinkProcess;
		
		//arrange chain
		Chain__c chain = new Chain__c(Name = 'testChain');
		insert chain;
		
		//arrange steps
		ChainStep__c step1 = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 1, Process__c = noopProcess.Id);
		ChainStep__c step2 = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 2, Process__c = noopProcess.Id);
		ChainStep__c step3 = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 3, Process__c = sinkProcess.Id);
		insert step1;
		insert step2;
		insert step3;
		
		//arrange arguments
		String testChain = 'testChain';
		Blob data = Blob.valueOf('herpderp');
		
		//act
		Broker.enqueue(testChain, data);
		
		//arrange
		Document document = [SELECT Id, Body FROM Document];
		
		//assert
		String expectedData = 'herpderp';
		String actualData = document.Body.toString();
		System.assertEquals(expectedData, actualData);
		
		//arrange
		PersistentData__c persistentData = [SELECT Id, Notification__c FROM PersistentData__c];
		Map<String,Object> notification = (Map<String,Object>)Json.deserializeUntyped(persistentData.Notification__c);
		
		//assert
		String expectedChainName = testChain;
		String actualChainName = (String)notification.get('eda__chainName');
		System.assertEquals(expectedChainName, actualChainName);
		
		Decimal expectedSequence = 0;
		Decimal actualSequence = (Decimal)notification.get('eda__sequence');
		System.assertEquals(expectedSequence, actualSequence);
	}
	
	static testmethod void testDodgyProcess() {
		//arrange process
		Process__c process = new Process__c(Name = 'BrokerTest.Dodgy');
		insert process;
		
		//arrange chain
		Chain__c chain = new Chain__c(Name = 'testChain');
		insert chain;
		
		//arrange step
		ChainStep__c step = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 1, Process__c = process.Id);
		insert step;
		
		//act
		Test.startTest();
		Broker.enqueue('testChain', '000000000000000AAA');
		Test.stopTest();
		
		//arrange
		PersistentData__c persistentData = [SELECT Id, Message__c FROM PersistentData__c];
		
		//asserts
		String expectedMessage = 'catchable';
		String actualMessage = persistentData.Message__c;
		System.assert(actualMessage.contains(expectedMessage));
	}
	
	//mock exception
	public class DodgyException extends Exception {}
	
	//mock process
	public class Dodgy implements Process.Plugin {
		public Process.PluginDescribeResult describe() {
			return new Process.PluginDescribeResult();
		}
		
		public Process.PluginResult invoke(Process.PluginRequest request) {
			throw new DodgyException('catchable');
			return Utility.convert(new List<Map<String,Object>>());
		}
	}
	
	static testMethod void testMalformedNotificationThrowsSystemJsonException() {
		//arrange
		PersistentData__c pd = new PersistentData__c(Notification__c = '{"malformed":...}');
		insert pd;
		
		//act
		Broker broker = new Broker();
		broker.execute(null, new List<SObject>{pd});
		
		//assert
		pd = [SELECT Id, Notification__c, Message__c FROM PersistentData__c WHERE Id = :pd.Id];
		String expectedMessage = 'json';
		String actualMessage = pd.Message__c;
		System.assert(actualMessage.contains(expectedMessage), actualMessage);
	}
	
	static testMethod void testMissingSequenceThrowsNullPointerException() {
		//arrange
		PersistentData__c pd = new PersistentData__c(Notification__c = '{"not_sequence": 0}');
		insert pd;
		
		//act
		Broker broker = new Broker();
		broker.execute(null, new List<SObject>{pd});
		
		//assert
		pd = [SELECT Id, Notification__c, Message__c FROM PersistentData__c WHERE Id = :pd.Id];
		String expectedMessage = 'Sequence';
		String actualMessage = pd.Message__c;
		System.assert(actualMessage.contains(expectedMessage), actualMessage);
	}
	
	static testMethod void testNoChainStepThrowsQueryException() {
		//arrange (note there is no ChainStep__c in database!)
		PersistentData__c pd = new PersistentData__c(Notification__c = '{"eda__chainName": "", "eda__sequence": 0}');
		insert pd;
		
		//act
		Broker broker = new Broker();
		broker.execute(null, new List<SObject>{pd});
		
		//assert
		pd = [SELECT Id, Notification__c, Message__c FROM PersistentData__c WHERE Id = :pd.Id];
		String expectedMessage = 'ChainStep';
		String actualMessage = pd.Message__c;
		System.assert(actualMessage.contains(expectedMessage), actualMessage);
	}
	
	static testMethod void testStupidProcessThrowsNullPointerException() {
		//arrange (note there is no Process__c in database!)
		Process__c process = new Process__c(Name = 'Sink');
		insert process; //let trigger create config as appropriate
		
		Chain__c chain = new Chain__c(Name = 'TestChain');
		insert chain;
		
		ChainStep__c chainStep = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 1, Process__c = process.Id);
		insert chainStep;
		
		process.Name = 'lalala';
		update process; //pretend we deleted the class
		
		PersistentData__c pd = new PersistentData__c(Notification__c = '{"eda__chainName": "TestChain", "eda__sequence": 0}');
		insert pd;
		
		//act
		Broker broker = new Broker();
		broker.execute(null, new List<SObject>{pd});
		
		//assert
		pd = [SELECT Id, Notification__c, Message__c FROM PersistentData__c WHERE Id = :pd.Id];
		String expectedMessage = 'class missing';
		String actualMessage = pd.Message__c;
		System.assert(actualMessage.contains(expectedMessage), actualMessage);
	}
	
	static testMethod void testNonProcessPluginThrowsTypeException() {
		//arrange (note there is no Process__c in database!)
		Process__c process = new Process__c(Name = 'Sink');
		insert process; //let trigger create config as appropriate
		
		Chain__c chain = new Chain__c(Name = 'TestChain');
		insert chain;
		
		ChainStep__c chainStep = new ChainStep__c(Chain__c = chain.Id, Sequence__c = 1, Process__c = process.Id);
		insert chainStep;
		
		process.Name = 'Account';
		update process; //this is definitely not a Process.Plugin
		
		PersistentData__c pd = new PersistentData__c(Notification__c = '{"eda__chainName": "TestChain", "eda__sequence": 0}');
		insert pd;
		
		//act
		Broker broker = new Broker();
		broker.execute(null, new List<SObject>{pd});
		
		//assert
		pd = [SELECT Id, Notification__c, Message__c FROM PersistentData__c WHERE Id = :pd.Id];
		String expectedMessage = 'interface';
		String actualMessage = pd.Message__c;
		System.assert(actualMessage.contains(expectedMessage), actualMessage);
	}
	
}