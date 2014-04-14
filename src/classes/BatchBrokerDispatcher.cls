public without sharing class BatchBrokerDispatcher implements Database.Batchable<SObject>, Database.AllowsCallouts {
    public Database.QueryLocator start(Database.BatchableContext context) {
        Database.Batchable<SObject> batch = (Database.Batchable<SObject>)Type.forName(BatchBrokerImplementation.class.getName()).newInstance();
        return (Database.QueryLocator)batch.start(context);
    }
    
    public void execute(Database.BatchableContext context, List<Message__c> scope) {
        Database.Batchable<SObject> batch = (Database.Batchable<SObject>)Type.forName(BatchBrokerImplementation.class.getName()).newInstance();
        batch.execute(context, scope);
    }
    
    public void finish(Database.BatchableContext context) {
        Database.Batchable<SObject> batch = (Database.Batchable<SObject>)Type.forName(BatchBrokerImplementation.class.getName()).newInstance();
        batch.finish(context);
    }
}