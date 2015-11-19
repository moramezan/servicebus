/**
 * This class is WITHOUT SHARING to ensure the service can execute regardless of running user context.
 */
public without sharing class BrokerBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    
    /**
     * Would have preferred to call the system interface, but
     * only top-level classes can implement Database.Batchable
     */
    public interface Batchable {
        Database.QueryLocator start(Database.BatchableContext context);
        void execute(Database.BatchableContext context, List<Sobject> scopes);
        void finish(Database.BatchableContext context);
    }
    
    Batchable batch = (Batchable)Type.forName('Broker.Batch').newInstance();
    
    public Database.QueryLocator start(Database.BatchableContext context) {
        return this.batch.start(context);
    }
    
    public void execute(Database.BatchableContext context, List<SObject> scopes) {
        this.batch.execute(context, scopes);
    }
    
    public void finish(Database.BatchableContext context) {
        this.batch.finish(context);
    }
    
}