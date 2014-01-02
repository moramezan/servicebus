@isTest public class ProcessRefreshBatchTest {
	
	static testMethod void testRecordCreatedForPlugin() {
		//arrange
		ProcessRefreshBatch batch = new ProcessRefreshBatch();
		batch.query += ' WHERE Name = \'Sink\'';
		
		//act
		Test.startTest();
		Database.executeBatch(batch);
		Test.stopTest();
		List<Process__c> processes = [SELECT Id, Name, Description__c FROM Process__c];
		
		//assert
		Integer expectedCount = 1;
		Integer actualCount = processes.size();
		System.assertEquals(expectedCount, actualCount);
		
		String expectedName = 'Sink';
		String actualName = processes[0].Name;
		System.assert(actualName.contains(expectedName));

		String expectedDescription = 'terminates all chains';
		String actualDescription = processes[0].Description__c;
		System.assert(actualDescription.contains(expectedDescription));
	}
	
}