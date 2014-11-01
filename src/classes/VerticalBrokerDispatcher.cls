/**
 * This class is WITHOUT SHARING to ensure the process can execute regardless of running user context.
 */
public without sharing class VerticalBrokerDispatcher implements Database.Batchable<Boolean>, Database.AllowsCallouts, Database.Stateful {
    
    private Database.Batchable<Boolean> batch = (Database.Batchable<Boolean>)Type.forName('VerticalBrokerImplementation').newInstance();
    
    public Iterable<Boolean> start(Database.BatchableContext context) {
        return (Iterable<Boolean>)this.batch.start(context);
    }
    
    public void execute(Database.BatchableContext context, List<Boolean> scopes) {
        this.batch.execute(context, scopes);
    }
    
    public void finish(Database.BatchableContext context) {
        this.batch.finish(context);
    }
    
}