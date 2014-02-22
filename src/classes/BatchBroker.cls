/**
 * This BatchBroker provides a worker process in Batch Apex that consumes off the Message queue. It will iterate
 * over a limited number, attempt to process those guys in their own execution context, and then restart the Batch Apex
 * job afterwards if more work remains. Simple in principle but can be very sluggish depending on resource availability.
 */
public with sharing class BatchBroker extends Broker implements Database.Batchable<SObject>, Database.AllowsCallouts {
    
    public Database.QueryLocator start(Database.BatchableContext context) {
        if (BrokerSettings__c.getInstance().Inhibit__c == true) System.assert(false, 'Inhibit'); //INHIBIT
        return this.locateMarkedWork(100);
    }
    
    public void execute(Database.BatchableContext context, List<Message__c> scope) {  
        Broker.executeResolvePersist(scope[0].Id);
    }
    
    public void finish(Database.BatchableContext context) {
        this.restartIfWorkPending();
    }
    
    /**
     * Each Broker implementation must provide the smarts of how to restart it.
     * The BatchBroker executes another Batch Apex job to run itself again.
     */
    override public void restartImpl() {
        Database.executeBatch(new BatchBroker(), 1);
    }
    
    override public Boolean isAlreadyRunning() {
        System.Type type = BatchBroker.class;
        String namespacePrefix;
        String name;
        
        if (type.getName().contains('.')) {
            //managed (namespaceprefix.classname)
            name = type.getName().substringBefore('.');
            namespacePrefix = type.getName().substringAfter('.');
        } else {
            //unmanaged (classname)
            name = type.getName();
            namespacePrefix = '';
        }
        
        //find existing jobs
        List<AsyncApexJob> existingJobs = [
            SELECT ApexClassId, JobType, Status, ExtendedStatus, JobItemsProcessed, TotalJobItems, LastProcessed 
            FROM AsyncApexJob
            WHERE ApexClass.NamespacePrefix = :namespacePrefix AND ApexClass.Name = :name
            AND JobType IN ('BatchApex')
            AND Status IN ('Queued', 'Processing', 'Preparing')
        ];
        
        return !existingJobs.isEmpty();
    }
}