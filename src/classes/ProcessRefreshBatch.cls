public with sharing class ProcessRefreshBatch implements Database.Batchable<SObject> {
    
    @testVisible private String query = 'SELECT Id, NamespacePrefix, Name FROM ApexClass ORDER BY Name ASC';
    
    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext context, List<ApexClass> scope) {
        List<Process__c> edaProcesses = new List<Process__c>();
        for (ApexClass apexClass : scope) {
            Type reflector = Type.forName(apexClass.NamespacePrefix, apexClass.Name);
            try {
                Process__c edaProcess = Processes.fromType(reflector);
                edaProcesses.add(edaProcess);
            } catch (Exception e) {
                //fuckup happened, probably
                //callout from constructor
            }
        }
        //will not duplicate existing processes
        upsert edaProcesses FullyQualifiedClassName__c;
    }
    
    public void finish(Database.BatchableContext context) {
        //
    }
    
}