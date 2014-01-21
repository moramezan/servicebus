public with sharing class Broker implements Database.Batchable<SObject>, Database.AllowsCallouts {

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
        doWork( persistentData);
    }    
 
    public void finish(Database.BatchableContext context) {
        Integer persistentDatas = [
            SELECT COUNT()
            FROM PersistentData__c
            WHERE RecordType.Name = 'Buffer'
        ];
        
        if (persistentDatas > 0) {
            //new stuff to do
            AsyncApexJobs.runOne(Broker.class, 1);
        }

        // empty recycle to remove form recents
        List<PersistentData__c> pds = [SELECT Id FROM PersistentData__c WHERE IsDeleted = true ALL ROWS];
        if (pds.size() > 0) Database.emptyRecycleBin(pds);
    }
    
    static public void enqueue(String chainName, Id data) {
        Integer sequence = 0;
        enqueue( chainName, data, sequence); // forward call onto zero-eth step on chain
    }

    static public void enqueue(String chainName, Blob data) {
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
    }
    
    static private void enqueue(String chainName, Id data, Integer sequence) {
        Map<String,Object> notification = new Map<String,Object> {
            'eda__chainName' => chainName,
            'eda__sequence' => sequence,  
            'id' => data
        };

        List<PersistentData__c> persistentDatas = new List<PersistentData__c> { 
            new  PersistentData__c (
                RecordTypeId = SObjectType.PersistentData__c.RecordTypeInfosByName.get('Buffer').RecordTypeId,
                Notification__c = Json.serializePretty(notification)
            ) 
        };

        writePersistentDatas (persistentDatas);
    }
 
    static private void writePersistentDatas(List<PersistentData__c> persistentDatas ) { 
        
        // before we insert, we need to 
        //   0. pull the notification  from persistent data
        //   1. resolve the next step in the chain (by incrementing the sequence by one)
        //   2A. convert 1. to a resolved chain step 
        //   2B. from 2A. resolve the the process  (ie the process referenced by this chainStep) 
        //   3. modify the notification properties to reflect 1.
        // only then can we correctly write to database with 2A (chainStepId)  and 3 ( notification with the incremeneted sequence)
        for (PersistentData__c  persistentData : persistentDatas ) {
            Map<String,Object> notification = (Map<String,Object>)Json.deserializeUntyped(persistentData.Notification__c); 
            notification.put('eda__sequence', (Decimal)notification.get('eda__sequence') + 1);
            ChainStep__c chainStep = [
                SELECT Id
                FROM ChainStep__c
                WHERE Chain__r.Name = :(String)notification.get('eda__chainName')
                AND Sequence__c = :(Decimal)notification.get('eda__sequence')
            ];  
            persistentData.Notification__c = Json.serializePretty(notification);
            persistentData.ChainStep__c = chainStep.Id;
        }

        insert persistentDatas;
    }
    
    @testVisible
    static private void doWork(PersistentData__c persistentData) {

        Map<String,Object> notification;
        List<Map<String,Object>> notifications = new List<Map<String,Object>>();
        Process.Plugin processable;
        
        // framework fuckups
        try {
            notification = (Map<String,Object>)Json.deserializeUntyped(persistentData.Notification__c);

            ChainStep__c chainStep = [
                SELECT Process__c, Configuration__c, Process__r.Name, Process__r.FullyQualifiedClassName__c
                FROM ChainStep__c
                WHERE Id = :persistentData.ChainStep__c
            ];
            

            notification.put('eda__configuration', chainStep.Configuration__c);

            //instantiate processable instance  
            Type reflector = Type.forName(chainStep.Process__r.FullyQualifiedClassName__c);
            processable = (Process.Plugin)reflector.newInstance();
            
        } catch (Exception e) {

            if (e instanceof System.JsonException) {
                e.setMessage('Could not deserialize json (malformed notification)');
            } else if (e instanceof System.NullPointerException) {
                e.setMessage('Sequence null (key missing from notification) or Type null (class missing)');
            } else if (e instanceof System.QueryException) {
                e.setMessage('ChainStep unqueryable (bad chain name, sequence, missing sink)');
            } else if (e instanceof System.TypeException) {
                e.setMessage('Could not cast Process.Plugin (interface unimplemented on process class)');
            }  
        
            surfaceException(  e , persistentData); 

            //get out of dodge quick
            return;
        }

        // eda processable plugin fuckups - could be anything !!!
        try {
            //call invoke the processable instance
            Process.PluginResult  results = processable.invoke(new Process.PluginRequest(notification));
            notifications = Utility.convert(results); 
        } catch (Exception e) {
            surfaceException(e, persistentData); 
            
            //get out of dodge quick
            return;
        }
        
        
        //delete successfully processed notification
        if (! Test.isRunningTest() ) {
            delete persistentData;
        }
        
        //Mark helper logic :
        //if markCount not null, increment and  THEN put that value on notification
        //if markCount equates to two, we assume the processing process was a splitter 
        //  and therefore write the count of the notifications returned from this splitter 
        //  as a property of the notification
        Decimal markCount = (Decimal)notification.get('eda__markCount');
        if (null != markCount) notification.put('eda__markCount', ++markCount);
        if (2 == markCount) {
            Integer count = notifications.size();
            notification.put('eda__count', count);
            if (count == 0) Database.delete(new List<Id>{(Id)notification.get('eda__gateGroupId')}); //tidy up split of 0
        }
    
        //wrap each notification in a buffered persistent data  instance and 
        //add each persistent data a persistentDatas list 
        String bufferId = SObjectType.PersistentData__c.RecordTypeInfosByName.get('Buffer').RecordTypeId;
         List<PersistentData__c> persistentDatas = new List<PersistentData__c>();
         for (Map<String,Object> n : notifications) {
             persistentDatas.add(new PersistentData__c(
                 Notification__c = Json.serializePretty(n),
                 RecordTypeId = bufferId
             ));
         }

        //write persistentDatas collection to database
        //these persistentDatas will be picked up in the next batch run
        writePersistentDatas (persistentDatas);
    }
    
    
    private static void surfaceException(Exception e, PersistentData__c persistentData) { 
      
        Map<String,Object> serializedException = new Map<String,Object>();
        serializedException.put('cause', e.getCause());
        serializedException.put('lineNumber', e.getLineNumber());
        serializedException.put('message', e.getMessage());
        serializedException.put('stackTraceString', e.getStackTraceString());
        serializedException.put('typeName', e.getTypeName());

        //log any exceptions
        //and record all details over 255 bytes using note object
        persistentData.Message__c = e.getMessage().left(255);
    
        // surface error - logic:
        // if it's a test and the persistent data id is null , we are ok with that , go no further
        // if it's a test and there is a persistent data  id, write details to database
        // if it's not a test and there is no persistent data  id , throw an exception
        // if it's not a test and there is a persistent data id, write details to database
        Boolean persistError =  false;
        if (Test.isRunningTest()) {  
            if(persistentData.Id == null) {
                return;
            } else {
                persistError =  true;
            }
        } else { // production
            if(persistentData.Id == null) {
                throw new BrokerException('Id for persistent data is null');
            } else {
                persistError =  true;
            }   
        }
        
        if (persistError) {
            update persistentData;
            insert new Note(
                ParentId = persistentData.Id,
                Title = e.getMessage().left(255),
                Body = System.Json.serializePretty(serializedException)
            );     
        }
    }
    
    private static Integer getQueryLimit(Integer fuckedLimit) {
        Integer fuckedCount = [
            SELECT COUNT()
            FROM PersistentData__c
            WHERE RecordType.Name = 'Processing'
        ];
        
        Integer reprocessCount = [
            SELECT COUNT()
            FROM PersistentData__c
            WHERE RecordType.Name = 'Reprocess'
        ];
        
        return  Math.max(0, fuckedLimit - fuckedCount) + reprocessCount;
    }
 

    private static Set<Id>  markEligiblePersistentDatasAsProcessing(Integer queryLimit) { 
        String processingId = SObjectType.PersistentData__c.RecordTypeInfosByName.get('Processing').RecordTypeId;
        
        //find some Buffer work, or if there's too many in Processing, only find Reprocess work
        Map<Id, PersistentData__c> id2data = new Map<Id, PersistentData__c>([
            SELECT Id
            FROM PersistentData__c
            WHERE RecordType.Name IN ('Reprocess', 'Buffer')
            ORDER BY RecordType.Name DESC
            LIMIT :queryLimit
        ]);
        
        for (PersistentData__c persistentData : id2data.values()) {
            persistentData.RecordTypeId = processingId;
        }
        
        update id2data.values();
        
        return id2data.keySet();
    }
    
}