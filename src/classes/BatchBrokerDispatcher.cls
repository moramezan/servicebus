/**
 * This class is WITHOUT SHARING to ensure the process can execute regardless of running user context.
 */
public without sharing class BatchBrokerDispatcher implements Database.Batchable<SObject>, Database.AllowsCallouts {
    public Database.QueryLocator start(Database.BatchableContext context) {
        Database.Batchable<SObject> batch = (Database.Batchable<SObject>)Type.forName('BatchBrokerImplementation').newInstance();
        return (Database.QueryLocator)batch.start(context);
    }
    
    public void execute(Database.BatchableContext context, List<Message__c> scope) {
        Database.Batchable<SObject> batch = (Database.Batchable<SObject>)Type.forName('BatchBrokerImplementation').newInstance();
        batch.execute(context, scope);
    }
    
    public void finish(Database.BatchableContext context) {
        Database.Batchable<SObject> batch = (Database.Batchable<SObject>)Type.forName('BatchBrokerImplementation').newInstance();
        batch.finish(context);
    }
}