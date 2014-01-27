public with sharing class BatchBroker extends Broker implements Database.Batchable<SObject>, Database.AllowsCallouts {

    public class BrokerException extends Exception {}

    public Database.QueryLocator start(Database.BatchableContext context) {  
        //prep:
        //  determine which persistent datas are eligible to be moved into the status of 'processing'
        //  note too many fucked persistent datas would be difficult to resolve so we 
        //  have an arbitary fucked limit which helps drive the size of the query 
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
        String  commaDelimitedProcessingIds = '(\'' + String.join(new List<Id>(processingIds), '\',\'') + '\')';
  
        //query locator :
        //  hand back persistent datas that were marked *in this execution context* (ie the start execution ctx) 
        //  as processing  
        return Database.getQueryLocator('SELECT Id, ChainStep__c, Notification__c FROM PersistentData__c WHERE Id IN ' + commaDelimitedProcessingIds);
    }
    
    public void execute(Database.BatchableContext context, List<SObject> scope) {  
        PersistentData__c persistentData = (PersistentData__c)scope[0]; //batch chunk always set to one
        
        //EXECUTE
        List<PersistentData__c> persistentDatas = super.execute(persistentData);
        
        //RESOLVE
        super.resolve(persistentDatas);
        
        //PERSIST
        insert persistentDatas;
    }    
 
    public void finish(Database.BatchableContext context) {
        Integer persistentDatas = [
            SELECT COUNT()
            FROM PersistentData__c
            WHERE Status__c = 'Buffer'
        ];
        
        if (persistentDatas > 0) {
            //new stuff to do
            AsyncApexJobs.runOne(BatchBroker.class, 1);
        }

        // empty recycle to remove form recents
        List<PersistentData__c> pds = [SELECT Id FROM PersistentData__c WHERE IsDeleted = true ALL ROWS];
        if (pds.size() > 0) Database.emptyRecycleBin(pds);
    }
    
    /*static public void enqueue(String chainName, Id data) {
        Integer sequence = 0;
        enqueue( chainName, data, sequence); // forward call onto zero-eth step on chain
    }*/

    /*static public void enqueue(String chainName, Blob data) {
        //prepare a very generic container
        Document document = new Document(
            Name = String.valueOf(Datetime.now().getTime()),
            Body = data,
            FolderId = UserInfo.getUserId(),
            ContentType = 'text/plain',
            Type = 'txt'
        );
        
        //store this data away and enqueue
        insert document;
        enqueue(chainName, document.Id);
    }*/
    
    /*static private void enqueue(String chainName, Id data, Integer sequence) {
        Map<String,Object> notification = new Map<String,Object> {
            'eda__chainName' => chainName,
            'eda__sequence' => sequence,  
            'id' => data
        };

        List<PersistentData__c> persistentDatas = new List<PersistentData__c> { 
            new  PersistentData__c (
                Status__c = 'Buffer',
                Notification__c = Json.serializePretty(notification)
            ) 
        };

        writePersistentDatas (persistentDatas);
    }*/
    
    override public void enqueueImpl(String chainName, Id data) {
        Map<String,Object> notification = new Map<String,Object> {
            'eda__chainName' => chainName,
            'eda__sequence' => 0,  
            'id' => data
        };

        List<PersistentData__c> persistentDatas = new List<PersistentData__c>{new PersistentData__c(
            Status__c = 'Buffer',
            Notification__c = Json.serializePretty(notification)
        )};

        //RESOLVE
        super.resolve(persistentDatas);
        
        //PERSIST
        insert persistentDatas;
    }
    
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
    
    private Set<Id> markEligiblePersistentDatasAsProcessing(Integer queryLimit) { 
        //find some Buffer work, or if there's too many in Processing, only find Reprocess work
        Set<Id> persistentDataIds = new Map<Id, PersistentData__c>([
            SELECT Id
            FROM PersistentData__c
            WHERE Status__c IN ('Reprocess', 'Buffer')
            ORDER BY Status__c DESC
            LIMIT :queryLimit
        ]).keySet();
        
        super.mark(persistentDataIds);
        return persistentDataIds;
    }
    
}