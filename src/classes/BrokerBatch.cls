/**
 * Dan Appleman decoupler pattern
 * Don't upgrade API version!
 * Don't modify class body!
 * It'll never reinstall!
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
    
    @TestVisible Batchable batch = (Batchable)Type.forName('Broker.BatchImpl').newInstance();
    
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