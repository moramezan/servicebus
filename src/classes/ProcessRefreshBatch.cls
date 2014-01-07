public class ProcessRefreshBatch implements Database.Batchable<SObject> {
	
	@testVisible private String query = 'SELECT Id, NamespacePrefix, Name FROM ApexClass';
	
	public Database.QueryLocator start(Database.BatchableContext context) {
		if (Test.isRunningTest()) this.query += ' LIMIT 1';
		return Database.getQueryLocator(query);
	}
	
	public void execute(Database.BatchableContext context, List<ApexClass> scope) {
		try {
			//implementors of Processable work alright here
			ApexClass apexClass = scope[0];
			Type reflector = Type.forName(apexClass.NamespacePrefix, apexClass.Name);
			Process.Plugin plugin = (Process.Plugin)reflector.newInstance();
			if (plugin instanceof Database.Stateful) {
				Process.PluginDescribeResult describeResult = plugin.describe();
				String description = (describeResult.Description != null) ? describeResult.Description.substringBefore('{') : null;
				Process__c process = new Process__c(
					Name = reflector.getName(),
					Description__c = description,
					Tag__c = describeResult.Tag 
				);
				upsert process Name; //will not duplicate existing processes
			}
		} catch (Exception e) {
			//non-implementors can fail hard in their own execution context
		}
	}
	
	public void finish(Database.BatchableContext context) {
		//
	}
	
}