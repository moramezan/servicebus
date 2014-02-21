/**
 * Very fundamental order:
 * 
 * Example chain:
 * TestChain #1 [Wiretap]
 * TestChain #2 [Wiretap]
 * TestChain #3 [Terminate]
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
 * 
 * 
 *
 * As used by a synchronous broker:
 *
 * +-----------+ (CONTEXT 1 FROM USER)
 * |  ENQUEUE  |
 * |           |
 * |  RESOLVE  |
 * |  PERSIST  |
 * |  MARK     |
 * |  EXECUTE  | invokes [Wiretap]
 * |  RESOLVE  |
 * |  PERSIST  |
 * |  MARK     |
 * |  EXECUTE  | invokes [Wiretap]
 * |  RESOLVE  |
 * |  PERSIST  |
 * |  MARK     |
 * |  EXECUTE  | invokes [Terminate]
 * +-----------+
 */
abstract global class Broker {
    
    global class BrokerException extends Exception {}
    
    /**
     * Determines which persistent datas are eligible to be moved into the Processing status (by finding Persistent
     * Datas with 'Reprocess' and 'Buffer' status). Note: too many fucked persistent datas would clog up the system,
     * so we have a global fuckedLimit.
     *
     * Persistent Datas that should be processed have their status marked as Processing in the database before being
     * submitted the query locator. That way, if any given execution fails, those persistent data will remain in the
     * easily identifiable 'Processing' state.
     *
     * @param workCount Maximum number of Persistent Datas to mark and locate (subject to fuckups)
     * @return          Query Locator identifying the now-marked-as-Processing Persistent Datas.
     */
    public Database.QueryLocator locateMarkedWork(Integer workCount) {
        Integer fuckedLimit = 100;
        
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
        
        //derives maximum number of Persistent Datas available for processing
        Integer queryLimit = Math.max(0, fuckedLimit - fuckedCount) + reprocessCount;
        
        Set<Id> persistentDataIds = new Map<Id,PersistentData__c>([
            SELECT Id
            FROM PersistentData__c
            WHERE Status__c IN ('Reprocess', 'Buffer')
            ORDER BY Status__c DESC
            LIMIT :Math.min(workCount, queryLimit)
        ]).keySet();
        
        //MARK
        this.markImpl(persistentDataIds);
        
        //query locator hands back only the persistent datas that were marked as processing
        String commaDelimitedIds = '(\'' + String.join(new List<Id>(persistentDataIds), '\',\'') + '\')';
        String queryString = 'SELECT Id, ChainStep__c, Parameters__c FROM PersistentData__c WHERE Id IN ' + commaDelimitedIds;
        return Database.getQueryLocator(queryString);
    }
    
    /**
     * Prepares data for processing at the start of a nominated chain by wrapping the pointer to the data (an id) in a
     * Persistent Data object. This Persistent Data instance is saved to the database and the Broker is immeadiately
     * invoked if it is not already running.
     *
     * @param chainName Name of the chain the data is destined for.
     * @param dataId    Id of some record that the chain will operate on.
     */
    static global void enqueue(String chainName, Id dataId) {
        Map<String,Object> parameters = new Map<String,Object> {
            'eda__chainName' => chainName,
            'eda__sequence' => 0,  
            'id' => dataId
        };
        
        List<PersistentData__c> persistentDatas = new List<PersistentData__c>{new PersistentData__c(
            Status__c = 'Buffer',
            Parameters__c = Json.serializePretty(parameters)
        )};
        
        //RESOLVE
        Broker.resolve(persistentDatas);
        
        //PERSIST
        insert persistentDatas;
        
        Broker.process();
    }
    
    static global void process() {
        BrokerSettings__c settings = BrokerSettings__c.getInstance();
        if (settings.BrokerClassName__c == null) settings.BrokerClassName__c = BatchBroker.class.getName(); //default
        
        Broker impl = (Broker)Type.forName(settings.BrokerClassName__c).newInstance();
        if (!impl.isAlreadyRunning()) impl.restartIfWorkPending();
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
    static public void mark(Set<Id> persistentDataIds) {
        List<PersistentData__c> persistentDatas = new List<PersistentData__c>();
        for (Id persistentDataId : persistentDataIds) {
            persistentDatas.add(new PersistentData__c(
                Id = persistentDataId,
                Status__c = 'Processing'
            ));
        }
        update persistentDatas;
    }
    
    virtual public void markImpl(Set<Id> persistentDataIds) {
        Broker.mark(persistentDataIds);
    }
    
    /**
     * Resolves and invokes the Process.Plugin for one input, handing back an in-memory collection of outputs
     * 
     * @param  persistentData One Persistent Data whose status should be Processing
     * @return                Many Persistent Datas whose status should be Buffer
     */
    static public void executeResolvePersist(Id persistentDataId) {
        PersistentData__c persistentData = (PersistentData__c)SalesforceObject.getById(persistentDataId);
        List<Map<String,Object>> parametersList;
        Map<String,Object> parameters;
        Process.Plugin plugin;
        
        //OUR FUCKUPS
        try {
            parameters = (Map<String,Object>)Json.deserializeUntyped(persistentData.Parameters__c);
    
            ChainStep__c chainStep = [
                SELECT Process__c, ConfigurationId__c, Process__r.Name, Process__r.FullyQualifiedClassName__c
                FROM ChainStep__c
                WHERE Id = :persistentData.ChainStep__c
            ];
        
            parameters.put('eda__configuration', chainStep.ConfigurationId__c);
        
            //instantiate processable instance  
            Type reflector = Type.forName(chainStep.Process__r.FullyQualifiedClassName__c);
            plugin = (Process.Plugin)reflector.newInstance();
        } catch (Exception e) {
            if (e instanceof System.JsonException) {
                e.setMessage('Could not deserialize json (malformed parameters)');
            } else if (e instanceof System.NullPointerException) {
                e.setMessage('Sequence null (key missing from parameters) or Type null (class missing)');
            } else if (e instanceof System.QueryException) {
                e.setMessage('ChainStep unqueryable (bad chain name, sequence, missing terminate)');
            } else if (e instanceof System.TypeException) {
                e.setMessage('Could not cast Process.Plugin (interface unimplemented on process class)');
            }
            surfaceException(e, persistentData.Id);
            return; //get out of dodge quick
        }
        
        //THEIR FUCKUPS
        try {
            //call invoke the processable instance
            Process.PluginResult results = plugin.invoke(new Process.PluginRequest(parameters));
            parametersList = Utility.convert(results);
        } catch (Exception e) {
            surfaceException(e, persistentData.Id);
            return; //get out of dodge quick
        }
        
        //delete successfully processed parameters
        delete persistentData;
        Database.emptyRecycleBin(persistentData);
        
        markHelper(parameters, parametersList);
        
        //wrap up parametersList into Persistent Datas
        List<PersistentData__c> persistentDatas = new List<PersistentData__c>();
        for (Map<String,Object> n : parametersList) {
            persistentDatas.add(new PersistentData__c(
                Parameters__c = Json.serializePretty(n),
                Status__c = 'Buffer'
            ));
        }
        
        //RESOLVE
        Broker.resolve(persistentDatas);
        
        //PERSIST
        insert persistentDatas;
    }

    /**
     * Increments parameters then resolves their destined Chain, Step, and Process.
     *
     * 1. hydrate the parameters from persistent data
     * 2. increments the sequence by one, ready to resolve the next step in the chain
     * 3. modify the parameters to reflect the new sequence
     * 4A. resolve the chain step from the parameters
     * 4B. resolve the the process (ie the process referenced by 4A's chainStep)
     * 5. only then can we correctly write to database with 4A (chainStepId) and 3 (parameters with the incremented sequence)
     */
    static public void resolve(List<PersistentData__c> persistentDatas) {
        //assemble a map of next-step keys to persistent datas
        Map<String,PersistentData__c> key2data = new Map<String,PersistentData__c>();
        for (PersistentData__c persistentData : persistentDatas) {
            Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(persistentData.Parameters__c);
            String chainName = (String)parameters.get('eda__chainName');
            Decimal sequence = (Decimal)parameters.get('eda__sequence') + 1; //care
            String key = chainName + '#' + sequence;
            key2data.put(key, persistentData);
            
            //increment the sequence and put it back while we're at it
            parameters.put('eda__sequence', sequence);
            persistentData.Parameters__c = Json.serializePretty(parameters);
        }
        
        //resolve the next chain steps and processes
        List<ChainStep__c> chainSteps = [
            SELECT Id, Process__r.Id, Chain__r.Id, ChainNameAndSequence__c
            FROM ChainStep__c
            WHERE ChainNameAndSequence__c IN :key2data.keySet()
        ];
        
        //assemble a map of next-step keys to steps
        Map<String,ChainStep__c> key2step = new Map<String,ChainStep__c>();
        for (ChainStep__c chainStep : chainSteps) key2step.put(chainStep.ChainNameAndSequence__c, chainStep);
        
        //now put the resolved chain/step/process on each persistentdata
        for (String key : key2data.keySet()) {
            ChainStep__c chainStep = key2step.get(key);
            PersistentData__c persistentData = key2data.get(key);
            
            persistentData.Chain__c = chainStep.Chain__r.Id;
            persistentData.Process__c = chainStep.Process__r.Id;
            persistentData.ChainStep__c = chainStep.Id;
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
        
        //log exception summary on parameters
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
    
    /**
     * The Mark helper logic is for the Gate process; it determines when a split occurs, and writes away the number of
     * splitted parameter sets so that a future Gate process can know exactly how many parameter sets form a Gate Group.
     *
     * If markCount isn't null, then the preceding process was a Mark; increment THEN put that value on parameters.
     * If markCount equates to two, then the preceding process was a splitter; write the count of split parameter sets.
     */
    @TestVisible
    private static void markHelper(Map<String,Object> parameters, List<Map<String,Object>> parametersList) {
        Decimal markCount = (Decimal)parameters.get('eda__markCount');
        if (null != markCount) parameters.put('eda__markCount', ++markCount);
        if (2 == markCount) {
            Integer count = parametersList.size();
            parameters.put('eda__count', count);
            if (count == 0) Database.delete(new List<Id>{(Id)parameters.get('eda__gateGroupId')}); //tidy up split of 0
        } 
     }
    
    public void restartIfWorkPending() {
        Integer worksPending = [
            SELECT COUNT()
            FROM PersistentData__c
            WHERE Status__c = 'Buffer'
            OR Status__c = 'Reprocess'
        ];
        
        if (worksPending > 0) {
            this.restartImpl();
        }
    }
    
    abstract global Boolean isAlreadyRunning();
     
    abstract global void restartImpl();
    
    @TestVisible public static String getNotificationId(Integer size) {
        return EncodingUtil.convertToHex(crypto.generateAesKey(128)).substring(0, size);
    }
}