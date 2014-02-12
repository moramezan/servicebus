public with sharing class BatchBroker extends Broker implements Database.Batchable<SObject>, Database.AllowsCallouts {

    public class BrokerException extends Exception {}

    public Database.QueryLocator start(Database.BatchableContext context) {  
    
        //MARK
        //  determine which persistent datas are eligible to be moved into the status of 'processing'
        //  note too many fucked persistent datas would be difficult to resolve so we 
        //  have an arbitrary fucked limit which helps drive the size of the query 
        //  locator. 
        //  Identified persistent datas that s/be processed  have their status marked as processing 
        //  in the database *in this execution context* (ie the start execution ctx) before being 
        //  submitted the query locator. That way, if any given execution fails, that persistent data
        //  will remain in the easily identifiable 'processing' state
        Integer fuckedLimit = 100;
        Integer queryLimit = getQueryLimit(fuckedLimit);
        if (queryLimit == 0) {
            System.abortJob(context.getJobId());
        }
        Set<Id> processingIds  = markEligiblePersistentDatasAsProcessing(queryLimit); 


        //query locator :
        //  hand back persistent datas that were marked *in this execution context* (ie the start execution ctx) 
        //  as processing  
        String  commaDelimitedProcessingIds = '(\'' + String.join(new List<Id>(processingIds), '\',\'') + '\')';
        String  queryString = 'SELECT Id, ChainStep__c, Notification__c FROM PersistentData__c WHERE Id IN ' + commaDelimitedProcessingIds;
        if (Test.isRunningTest()) {
            queryString = queryString + ' LIMIT 1';
        }
        
        return Database.getQueryLocator( queryString );
    }
    
    public void execute(Database.BatchableContext context, List<SObject> scope) {  
        PersistentData__c persistentData = (PersistentData__c)scope[0]; //batch chunk always set to one
        
        //EXECUTE
        List<PersistentData__c> persistentDatas = super.execute(persistentData);
        
        //RESOLVE
        //PERSIST
        resolveAndPersist(  persistentDatas);
        
    }    
 
    public void finish(Database.BatchableContext context) {
        //MARK (delegation) 
        //EXECUTE (delegation)
        if (!Test.isRunningTest()) {
            startBatch();
        } 
    }
    
    
    public override void startImpl() {
        //MARK (delegation) 
        //EXECUTE (delegation)
        startBatch();
    }
    
    /**
     * Resolves, persists  a single Persistent Data
     * then starts the Batch which will in turn 
     * mark this (Buffered) Persistent Data ( with a status of Processing)
     * 
     * @param chainName Name of the chain he is destined for.
     * @param dataId    Id of some record that the chain will operate on.
     */
    override public void enqueueImpl(String chainName, Id data) {
        Map<String,Object> notification = new Map<String,Object> {
            'eda__notificationId' => Broker.getNotificationId(18),
            'eda__chainName' => chainName,
            'eda__sequence' => 0,  
            'id' => data
        };

        List<PersistentData__c> persistentDatas = new List<PersistentData__c>{new PersistentData__c(
            Status__c = 'Buffer',
            Notification__c = Json.serializePretty(notification)
        )};

        //RESOLVE
        //PERSIST
        resolveAndPersist(  persistentDatas);

        //MARK (delegation) 
        //EXECUTE (delegation)
        startBatch();
    }
    
    @TestVisible
    private   void resolveAndPersist(List<PersistentData__c> persistentDatas) {
        //RESOLVE
        super.resolve(persistentDatas);
        
        //PERSIST
        insert persistentDatas; 
    }
   
    private static void startBatch() {
        Integer persistentDatasCount = [
            SELECT COUNT()
            FROM PersistentData__c
            WHERE Status__c = 'Buffer'
            OR Status__c = 'Reprocess'
        ];
        
        if (persistentDatasCount > 0) {
            AsyncApexJobs.runOne(BatchBroker.class, 1);
        } 
    }

    @TestVisible
    private static Integer getQueryLimit(Integer fuckedLimit) {
        Integer fuckedCount = [
            SELECT COUNT()
            FROM PersistentData__c
            WHERE Status__c = 'Processing'
        ];
        
        Integer reprocessCount = [
            SELECT COUNT()
            FROM PersistentData__c
            WHERE Status__c = 'Reprocess'
        ];
        
        return  Math.max(0, fuckedLimit - fuckedCount) + reprocessCount;
    }
  
    /**
     * Find Persistent Datas with  Buffer and Reprocess status
     * If too many in Persistent Datas found, limit eligible Persistent Datas
     * to only those with a Reprocess status
     * Mark these Persistent datas with a status of Processing
     *
     * @param queryLimit defines maximum number of Persistent Datas available for processing
     *
     */  
    @TestVisible
    private Set<Id> markEligiblePersistentDatasAsProcessing(Integer queryLimit) { 
        Set<Id> persistentDataIds = new Map<Id, PersistentData__c>([
            SELECT Id
            FROM PersistentData__c
            WHERE Status__c IN ('Reprocess', 'Buffer')
            ORDER BY Status__c DESC
            LIMIT :queryLimit
        ]).keySet();
        
        //MARK
        super.mark(persistentDataIds);
        
        return persistentDataIds;
    }
}