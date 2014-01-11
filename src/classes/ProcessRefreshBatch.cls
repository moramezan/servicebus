public with sharing class ProcessRefreshBatch implements Database.Batchable<SObject> {
    
    @testVisible private String query = 'SELECT Id, NamespacePrefix, Name FROM ApexClass';
    
    public Database.QueryLocator start(Database.BatchableContext context) {
        if (Test.isRunningTest()) this.query += ' LIMIT 1';
        return Database.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext context, List<ApexClass> scope) {       
        List<Process__c> processes = new ApexClasses(scope).regenerate();
        upsert processes Name; //will not duplicate existing processes
    }
    
    public void finish(Database.BatchableContext context) {
        //
    }
    
}