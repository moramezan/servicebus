/**
 * Very fundamental order:
 * 
 * Example chain:
 * TestChain #1 [Wiretap]
 * TestChain #2 [Wiretap]
 * TestChain #3 [Terminate]
 *
 * As used by a recursing broker:
 *
 * +-----------+ (CONTEXT 1 FROM USER)
 * |  ENQUEUE  |
 * |           |
 * |  RESOLVE  |
 * |  PERSIST  |
 * |  MARK     |
 * +-----------+
 *
 * +-----------+ (CONTEXT 2)
 * |  EXECUTE  | invokes [Wiretap]
 * |  RESOLVE  |
 * |  PERSIST  |
 * |  MARK     |
 * +-----------+
 *
 * +-----------+ (CONTEXT 3)
 * |  EXECUTE  | invokes [Wiretap]
 * |  RESOLVE  |
 * |  PERSIST  |
 * |  MARK     |
 * +-----------+
 *
 * +-----------+ (CONTEXT 4)
 * |  EXECUTE  | invokes [Terminate]
 * +-----------+
 *
 *
 *
 * As used by a queueing broker:
 *
 * +-----------+ (CONTEXT 1 FROM USER)
 * |  ENQUEUE  |
 * +-----------+
 *
 * +-----------+ (CONTEXT 2 batchable.start)
 * |  MARK     | we need to "dirty" these guys with PROCESSING status in case they fuck up
 * +-----------+
 *
 * +-----------+ (CONTEXT 3 batchable.execute)
 * |  EXECUTE  | invokes [Wiretap]
 * |  RESOLVE  | ensures all generated persistentdatas never
 * |  PERSIST  | exist in an unresolved state per issue #100
 * +-----------+
 *
 * +-----------+ (CONTEXT 4 batchable.finish)
 * |  ENQUEUE  |
 * +-----------+
 *
 * +-----------+ (CONTEXT 5 batchable.start)
 * |  MARK     | 
 * +-----------+
 *
 * +-----------+ (CONTEXT 6 batchable.execute)
 * |  EXECUTE  | invokes [Wiretap]
 * |  RESOLVE  | 
 * |  PERSIST  | 
 * +-----------+
 *
 * +-----------+ (CONTEXT 7 batchable.finish)
 * |  ENQUEUE  |
 * +-----------+
 *
 * +-----------+ (CONTEXT 8 batchable.start)
 * |  MARK     | 
 * +-----------+
 *
 * +-----------+ (CONTEXT 9 batchable.execute)
 * |  EXECUTE  | invokes [Terminate]
 * |  RESOLVE  | 
 * |  PERSIST  | 
 * +-----------+
 *
 * +-----------+ (CONTEXT 10 batchable.finish)
 * |  ENQUEUE  |
 * +-----------+
 */
abstract global class Broker {
    
    public class BrokerException extends Exception {}
    
    
     /**
     * Starts the Broker
     *
     */
    static global void start() {
        BrokerSettings__c settings = BrokerSettings__c.getInstance();
        if (settings.BrokerClassName__c == null) {
            //default
            Broker broker = new BatchBroker();
            broker.startImpl();
        } else {
            //override
            Broker broker = (Broker)Type.forName(settings.BrokerClassName__c).newInstance();
            broker.startImpl();
        } 
    }
    
    
    /**
     * Prepares data for processing at the start of a nominated chain 
     * by wrapping the pointer to the data (an id) in a Persistent Data object
     * This Persisted Data instance is saved to the database and the Broker is
     * immeadiately invoked threreafter   
     *
     * @param chainName Name of the chain the data is destined for.
     * @param dataId    Id of some record that the chain will operate on.
     */ 
    static global void enqueue(String chainName, Id dataId) {
        BrokerSettings__c settings = BrokerSettings__c.getInstance();
        if (settings.BrokerClassName__c == null) {
            //default
            Broker broker = new BatchBroker();
            broker.enqueueImpl(chainName, dataId);
        } else {
            //override
           Broker broker = (Broker)Type.forName(settings.BrokerClassName__c).newInstance();
           broker.enqueueImpl(chainName, dataId);
        }
    }
    
    
    /**
     * Prepares Blob data for processing at the start of a nominated chain 
     * by wrapping the pointer to the data (an id) in a Persistent Data object
     * This Persisted Data instance is saved to the database and the Broker is
     * immeadiately invoked threreafter   
     *
     * @param chainName Name of the chain the data is destined for.
     * @param dataId    Blob representation of the data the chain will operate on.
     */ 
    static global void enqueue(String chainName, Blob data) {
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
    
 
    
    /**
     * Sets many Persistent Datas statuses to 'Processing' and writes them away.
     *
     * @param persistentDataIds Set of Persistent Data Ids to update
     */
    public void mark(Set<Id> persistentDataIds) {
        List<PersistentData__c> persistentDatas = [SELECT Id FROM PersistentData__c WHERE Id IN :persistentDataIds];
        for (PersistentData__c persistentData : persistentDatas) {
            persistentData.Status__c = 'Processing';
        }
        
        update persistentDatas;
    }
    
    /**
     * Resolves and invokes the Process.Plugin for one input, handing back an in-memory collection of outputs
     * 
     * @param  persistentData One Persistent Data whose status should be Processing
     * @return                Many Persistent Datas whose status should be Buffer
     */
    public List<PersistentData__c> execute(PersistentData__c persistentData) {
        List<Map<String,Object>> notifications;
        Map<String,Object> notification;
        Process.Plugin plugin;
        
        //OUR FUCKUPS
        try {
            notification = (Map<String,Object>)Json.deserializeUntyped(persistentData.Notification__c);
    
            ChainStep__c chainStep = [
                SELECT Process__c, ConfigurationId__c, Process__r.Name, Process__r.FullyQualifiedClassName__c
                FROM ChainStep__c
                WHERE Id = :persistentData.ChainStep__c
            ];
        
            notification.put('eda__configuration', chainStep.ConfigurationId__c);
        
            //instantiate processable instance  
            Type reflector = Type.forName(chainStep.Process__r.FullyQualifiedClassName__c);
            plugin = (Process.Plugin)reflector.newInstance();
        } catch (Exception e) {
            if (e instanceof System.JsonException) {
                e.setMessage('Could not deserialize json (malformed notification)');
            } else if (e instanceof System.NullPointerException) {
                e.setMessage('Sequence null (key missing from notification) or Type null (class missing)');
            } else if (e instanceof System.QueryException) {
                e.setMessage('ChainStep unqueryable (bad chain name, sequence, missing terminate)');
            } else if (e instanceof System.TypeException) {
                e.setMessage('Could not cast Process.Plugin (interface unimplemented on process class)');
            }
            surfaceException(e, persistentData.Id);
            return new List<PersistentData__c>(); //get out of dodge quick
        }
        
        //THEIR FUCKUPS
        try {
            //call invoke the processable instance
            Process.PluginResult results = plugin.invoke(new Process.PluginRequest(notification));
            notifications = Utility.convert(results);
        } catch (Exception e) {
            surfaceException(e, persistentData.Id);
            return new List<PersistentData__c>(); //get out of dodge quick
        }
        
        //delete successfully processed notification
        delete persistentData;
        purgePersistentDatas();
        
        //Mark helper logic :
        //if markCount not null, increment and  THEN put that value on notification
        //if markCount equates to two, we assume the processing process was a splitter 
        //  and therefore write the count of the notifications returned from this splitter 
        //  as a property of the notification
        markHelper( notification, notifications);
 
        //wrap each notification in a buffered persistent data  instance and 
        //add each persistent data a persistentDatas list 
        List<PersistentData__c> persistentDatas = wrapNotifications(notifications);
 
        return persistentDatas;
    }

    /**
     * Increments notifications then resolves their destined Chain, Step, and Process.
     *
     * 1. hydrate the notification from persistent data
     * 2. increments the sequence by one, ready to resolve the next step in the chain
     * 3. modify the notification properties to reflect the new sequence
     * 4A. resolve the chain step from the notification
     * 4B. resolve the the process (ie the process referenced by 4A's chainStep)
     * 5. only then can we correctly write to database with 4A (chainStepId) and 3 (notification with the incremented sequence)
     *
     * //TODO implement more efficient bulkified version 
     */
    @TestVisible    
    public void resolve(List<PersistentData__c> persistentDatas) {
        String delim = '###';
        Map<String,Map<String,Object>> keyToDetail = new Map<String,Map<String,Object>> ();
        Set<String> chainNames = new Set<String>();
        Set<Decimal> sequences = new Set<Decimal>();
        for (PersistentData__c  persistentData : persistentDatas ) {
            Map<String,Object> notification = (Map<String,Object>)Json.deserializeUntyped(persistentData.Notification__c); 
            String chainName = (String)notification.get('eda__chainName');
            Decimal sequence = (Decimal)notification.get('eda__sequence') + 1;
            notification.put('eda__sequence', sequence);
            String key = chainName + delim + sequence; 
            chainNames.add(chainName);
            sequences.add(sequence);
            Map<String,Object> keyToAttribute = new  Map<String,Object>{
                'notification' =>  notification,
                'persistentData' => persistentData
            };
            keyToDetail.put(key, keyToAttribute);
         }
    
        Map<String, ChainStep__c> keyToChainStep = new Map<String, ChainStep__c> ();
        List<ChainStep__c> chainSteps = [
            SELECT Id, Chain__r.Id, Process__r.Id, Chain__r.Name, Sequence__c 
            FROM ChainStep__c
            WHERE Chain__r.Name IN :chainNames 
            OR Sequence__c IN :sequences
        ];
        for (ChainStep__c chainStep : chainSteps) {
            String key = chainStep.Chain__r.Name + delim + chainStep.Sequence__c; 
            keyToChainStep.put(key , chainStep);
        }
        
                
        persistentDatas.clear();
        for (String key :  keyToDetail.keySet()) {
            ChainStep__c chainStep = (ChainStep__c) keyToChainStep.get(key);   
            Map<String,Object> keyToAttribute = (Map<String,Object>) keyToDetail.get(key);
            PersistentData__c persistentData =  (PersistentData__c) keyToAttribute.get('persistentData');
            Map<String,Object> notification =   (Map<String,Object>) keyToAttribute.get('notification');
            
            persistentData.Notification__c = Json.serializePretty(notification);
            persistentData.Process__c = chainStep.Process__r.Id;
            persistentData.ChainStep__c = chainStep.Id;
            persistentData.Chain__c = chainStep.Chain__r.Id;
            persistentDatas.add(persistentData); 
        }
    }
    
    @TestVisible
    private static void surfaceException(Exception e, Id persistentDataId) { 
        Map<String,Object> serializedException = new Map<String,Object>();
        serializedException.put('cause', e.getCause());
        serializedException.put('lineNumber', e.getLineNumber());
        serializedException.put('message', e.getMessage());
        serializedException.put('stackTraceString', e.getStackTraceString());
        serializedException.put('typeName', e.getTypeName());
        
        //log exception summary on notification
        Database.update(new PersistentData__c(
            Id = persistentDataId,
            Message__c = e.getMessage().left(255)
        ));
        
        //log exception details over 255 bytes using note object
        insert new Note(
            ParentId = persistentDataId,
            Title = e.getMessage().left(80),
            Body = Json.serializePretty(serializedException).left(32000)
        );
    }
    
    
    /*
     * wrap each notification in a buffered persistent data  instance and 
     * adds each persistent data a persistentDatas list 
     */
    @TestVisible
    private static List<PersistentData__c>  wrapNotifications(List<Map<String,Object>>  notifications ) {
        List<PersistentData__c> persistentDatas = new List<PersistentData__c>();
        for (Map<String,Object> n : notifications) {
            persistentDatas.add(new PersistentData__c(
                Notification__c = Json.serializePretty(n),
                Status__c = 'Buffer'
            ));
        }
        
        return persistentDatas;
     }
            
    
    /**
     * Mark helper logic :
     * if markCount not null, increment and  THEN put that value on notification
     * if markCount equates to two, we assume the  process.plugin was a splitter 
     *   and therefore write the count of the notifications returned from this splitter 
     *   as a property of the notification
     */
    @TestVisible
    private static void  markHelper(Map<String,Object> notification,  List<Map<String,Object>>  notifications) {
        Decimal markCount = (Decimal)notification.get('eda__markCount');
        if (null != markCount) notification.put('eda__markCount', ++markCount);
        if (2 == markCount) {
            Integer count = notifications.size();
            notification.put('eda__count', count);
            if (count == 0) Database.delete(new List<Id>{(Id)notification.get('eda__gateGroupId')}); //tidy up split of 0
        } 
     }

    /**
     *  empties recycle bin to remove from recents
     *  note : it appears that Database.emptyRecycleBin() does not work under 
     *         a test eneviroment, hence no unit test for this method
     */
    @TestVisible
    private static  void purgePersistentDatas() {      
        List<PersistentData__c> pds = [SELECT Id FROM PersistentData__c WHERE IsDeleted = true ALL ROWS];
        if (pds.size() > 0) Database.emptyRecycleBin(pds);
    }
    
    
    /**
     * Persists a single piece of data in a named chain and
     * immeadiately starts the (configured) Broker
     *
     * @param chainName Name of target Chain
     * @param dataId    Id of SObject to operate upon
     */
     abstract global void enqueueImpl(String chainName, Id dataId);
 
     /**
     * Starts the (configured) Broker
     *
     */    
     abstract global void  startImpl() ;
}