/**
 * This class is WITHOUT SHARING to ensure the process can execute regardless of running user context.
 */
public without sharing class BatchBrokerDispatcher implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    
    private Database.Batchable<SObject> batch = (Database.Batchable<SObject>)Type.forName('BatchBrokerImplementation').newInstance();
    
    public Database.QueryLocator start(Database.BatchableContext context) {
        return (Database.QueryLocator)this.batch.start(context);
    }
    
    public void execute(Database.BatchableContext context, List<Message__c> scope) {
        this.batch.execute(context, scope);
    }
    
    public void finish(Database.BatchableContext context) {
        this.batch.finish(context);
    }
}