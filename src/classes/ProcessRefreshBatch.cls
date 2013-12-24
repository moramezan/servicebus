public class ProcessRefreshBatch implements Database.Batchable<SObject> {
	
	public Database.QueryLocator start(Database.BatchableContext context) {
		return Database.getQueryLocator('SELECT Id, NamespacePrefix, Name FROM ApexClass');
	}
	
	public void execute(Database.BatchableContext context, List<ApexClass> scope) {
		try {
			//implementors of Processable work alright here
			ApexClass apexClass = scope[0];
			Type reflector = Type.forName(apexClass.NamespacePrefix, apexClass.Name);
			Processable processable = (Processable)reflector.newInstance();
			Process__c process = new Process__c(Name = reflector.getName());
			upsert process Name; //will not duplicate existing processes
		} catch (Exception e) {
			//non-implementors can fail hard in their own execution context
		}
	}
	
	public void finish(Database.BatchableContext context) {
		//
	}
	
}