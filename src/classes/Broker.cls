/**
 * Very fundamental order:
 *
 * Example sequence:
 * TestSequence #1 [Wiretap]
 * TestSequence #2 [Wiretap]
 * TestSequence #3 [Terminate]
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
 * |  RESOLVE  | ensures all generated messages never
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
    
    @TestVisible
    private static Integer stackDepthThreshold  = 500;
    
    global class BrokerException extends Exception {}
    
    /**
     * Determines which messages are eligible to be moved into the Processing status (by finding Messages
     * with 'Reprocess' and 'Buffer' status). Note: too many fucked messages would clog up the system,
     * so we have a global fuckedLimit.
     *
     * Messages that should be processed have their status marked as Processing in the database before being
     * submitted the query locator. That way, if any given execution fails, those messages will remain in the
     * easily identifiable 'Processing' state.
     *
     * @param workCount Maximum number of Messages to mark and locate (subject to fuckups)
     * @return          Query Locator identifying the now-marked-as-Processing Messages.
     */
    public Database.QueryLocator locateMarkedWork(Integer workCount) {
        Integer fuckedLimit = 100;
        
        Integer fuckedCount = [
            SELECT COUNT()
            FROM Message__c
            WHERE Status__c = 'Processing'
        ];
        
        Integer reprocessCount = [
            SELECT COUNT()
            FROM Message__c
            WHERE Status__c = 'Reprocess'
        ];
        
        //derives maximum number of Messages available for processing
        Integer queryLimit = Math.max(0, fuckedLimit - fuckedCount) + reprocessCount;
        
        Set<Id> messageIds = new Map<Id,Message__c>([
            SELECT Id
            FROM Message__c
            WHERE Status__c IN ('Reprocess', 'Buffer')
            ORDER BY Status__c DESC
            LIMIT :Math.min(workCount, queryLimit)
        ]).keySet();
        
        //MARK
        this.markImpl(messageIds);
        
        //query locator hands back only the messages that were marked as processing
        String commaDelimitedIds = '(\'' + String.join(new List<Id>(messageIds), '\',\'') + '\')';
        String queryString = 'SELECT Id, Step__c, Parameters__c FROM Message__c WHERE Id IN ' + commaDelimitedIds;
        return Database.getQueryLocator(queryString);
    }
    
    /**
     * Prepares data for processing at the start of a nominated sequence by wrapping the pointer to the data (an id) in a
     * Message object. This Message instance is saved to the database and the Broker is immeadiately
     * invoked if it is not already running.
     *
     * @param sequenceName Name of the sequence the data is destined for.
     * @param dataId    Id of some record that the sequence will operate on.
     */
    static global void enqueue(String sequenceName, Id dataId) {
        Map<String,Object> parameters = new Map<String,Object> {
            'eda_notificationGuid' => getNotificationGuid(18),
            'eda_sequenceName' => sequenceName,
            'eda_position' => 0,
            'Id' => dataId
        };
        
        //create the message destined for the 0th step of the chain
        Message__c message = new Message__c(Parameters__c = Json.serializePretty(parameters));
        
        //fetch the custom setting or create an empty one
        BrokerSettings__c setting = BrokerSettings__c.getOrgDefaults();
        if (setting == null) setting = new BrokerSettings__c();
        
        if (setting.IsPaused__c) {
            //system is paused
            //Why aren't these Messages resolved?
            //Because their pointers would be a misrepresentation of their destination
            //if the system had been rearranged during the time it was paused.
            message.Status__c = 'Queued';
        } else {
            //system is running
            message.Status__c = 'Buffer';
            Broker.resolve(new List<Message__c>{message}); //RESOLVE
        }
        
        insert message; //PERSIST
        Broker.process();
    }
    
    static global void process() {
        BrokerSettings__c settings = BrokerSettings__c.getInstance();
		if (settings.BrokerClassName__c == null) settings.BrokerClassName__c = BatchBrokerImplementation.class.getName(); 
        
        Broker impl = (Broker)Type.forName(settings.BrokerClassName__c).newInstance();
        if (!impl.isAlreadyRunning()) impl.restartIfWorkPending();
    }
    
    /**
     * Prepares Blob data for processing at the start of a nominated sequence
     * by wrapping the pointer to the data (an id) in a Message object
     * This Persisted Data instance is saved to the database and the Broker is
     * immeadiately invoked threreafter
     *
     * @param sequenceName Name of the sequence the data is destined for.
     * @param dataId    Blob representation of the data the sequence will operate on.
     */
    static global void enqueue(String sequenceName, Blob data) {
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
        enqueue(sequenceName, document.Id);
    }
    
    /**
     * Sets many Messages statuses to 'Processing' and writes them away.
     *
     * @param messageIds Set of Message Ids to update
     */
    static public void mark(Set<Id> messageIds) {
        List<Message__c> messages = new List<Message__c>();
        for (Id messageId : messageIds) {
            messages.add(new Message__c(
                Id = messageId,
                Status__c = 'Processing'
            ));
        }
        update messages;
    }
    
    virtual public void markImpl(Set<Id> messageIds) {
        Broker.mark(messageIds);
    }
    
    /**
     * Resolves and invokes the Process.Plugin for one input, handing back an in-memory collection of outputs
     *
     * @param  message One Message whose status should be Processing
     * @return         Many Messages whose status should be Buffer
     */
    static public void executeResolvePersist(Id messageId) {
        Message__c message = (Message__c)SalesforceObject.getById(messageId);
        List<Map<String,Object>> parametersList;
        Map<String,Object> parameters;
        Process.Plugin plugin;
        
        //OUR FUCKUPS
        try {
            parameters = (Map<String,Object>)Json.deserializeUntyped(message.Parameters__c);
    
            Step__c step = [
                SELECT Process__c, ConfigurationId__c, Process__r.Name, Process__r.FullyQualifiedClassName__c
                FROM Step__c
                WHERE Id = :message.Step__c
            ];
        
            parameters.put('eda_configuration', Step.ConfigurationId__c);
        
            //instantiate processable instance
            Type reflector = Type.forName(Step.Process__r.FullyQualifiedClassName__c);
            plugin = (Process.Plugin)reflector.newInstance();
        } catch (Exception e) {
            if (e instanceof System.JsonException) {
                e.setMessage('Could not deserialize json (malformed parameters)');
            } else if (e instanceof System.NullPointerException) {
                e.setMessage('Position null (key missing from parameters) or Type null (class missing)');
            } else if (e instanceof System.QueryException) {
                e.setMessage('Step unqueryable (bad sequence name, position, missing terminate)');
            } else if (e instanceof System.TypeException) {
                e.setMessage('Could not cast Process.Plugin (interface unimplemented on process class)');
            }
            surfaceException(e, message.Id);
            return; //get out of dodge quick
        }
        
        //THEIR FUCKUPS
        try {
            //save important message properties (such as stackDepth) so that process authors 
            //cannot pervert them  
            //TODO : requires a more generic approach not specific to just the eda_stackDepth
            //       property
            Integer stackDepth = getStackDepth(parameters, stackDepthThreshold);
            //call invoke the processable instance
            Process.PluginResult results = plugin.invoke(new Process.PluginRequest(parameters));
            //write back save important message properties 
            //TODO : requires a more generic approach to write back the "eda_" properties to 
            //       the parameters collections in parametersList
            results = applyStackDepth(results, stackDepth);
            // convert to a list of parameter collections
            parametersList = EdaUtility.convert(results);
        } catch (Exception e) {
            surfaceException(e, message.Id);
            return; //get out of dodge quick
        }
        
        //delete successfully processed parameters
        delete message;
        Database.emptyRecycleBin(message);
        
        markHelper(parameters, parametersList);
        
        //wrap up parametersList into Messages
        List<Message__c> messages = new List<Message__c>();
        for (Map<String,Object> n : parametersList) {
            messages.add(new Message__c(
                Parameters__c = Json.serializePretty(n),
                Status__c = 'Buffer'
            ));
        }
        
        //RESOLVE
        Broker.resolve(messages);
        
        //PERSIST
        insert messages;
    }

    /**
     * Increments parameters then resolves their destined Sequence, Step, and Process.
     *
     * 1. hydrate the parameters from message
     * 2. increments the position by one, ready to resolve the next step in the sequence
     * 3. modify the parameters to reflect the new position
     * 4A. resolve the step from the parameters
     * 4B. resolve the the process (ie the process referenced by 4A's step)
     * 5. only then can we correctly write to database with 4A (stepId) and 3 (parameters with the incremented position)
     */
    static public void resolve(List<Message__c> messages) {
        //assemble a map of next-step keys to messages
        Map<String,Message__c> key2data = new Map<String,Message__c>();
        for (Message__c message : messages) {
            Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(message.Parameters__c);
            String sequenceName = (String)parameters.get('eda_sequenceName');
            Decimal position = (Decimal)parameters.get('eda_position') + 1; //care
            String key = sequenceName + '#' + position;
            key2data.put(key, message);
            
            //increment the position and put it back while we're at it
            parameters.put('eda_position', position);
            message.Parameters__c = Json.serializePretty(parameters);
        }
        
        //resolve the next steps and processes
        List<Step__c> steps = [
            SELECT Id, Process__r.Id, Sequence__r.Id, SequenceNameAndPosition__c
            FROM Step__c
            WHERE SequenceNameAndPosition__c IN :key2data.keySet()
        ];
        
        //assemble a map of next-step keys to steps
        Map<String,Step__c> key2step = new Map<String,Step__c>();
        for (Step__c step : steps) key2step.put(step.SequenceNameAndPosition__c, step);
        
        //now put the resolved sequence/step/process on each message
        for (String key : key2data.keySet()) {
            Step__c step = key2step.get(key);
            Message__c message = key2data.get(key);
            
            message.Sequence__c = step.Sequence__r.Id;
            message.Process__c = step.Process__r.Id;
            message.Step__c = step.Id;
        }
    }
    
    @TestVisible
    private static void surfaceException(Exception e, Id messageId) {
        Map<String,Object> serializedException = new Map<String,Object>();
        serializedException.put('cause', e.getCause());
        serializedException.put('lineNumber', e.getLineNumber());
        serializedException.put('message', e.getMessage());
        serializedException.put('stackTraceString', e.getStackTraceString());
        serializedException.put('typeName', e.getTypeName());
        
        //log exception summary on parameters
        Database.update(new Message__c(
            Id = messageId,
            Message__c = e.getMessage().left(255)
        ));
        
        //log exception details over 255 bytes using note object
        insert new Note(
            ParentId = messageId,
            Title = e.getMessage().left(80),
            Body = Json.serializePretty(serializedException).left(32000)
        );
    }

     /**
     * Context:
     * A message can pass through a limited number of steps. This "limit" is a fairly high arbitrary threshold.
     * The intent is to prevent a never ending self referencing loop (we cannot control what the system configurators
     * configure). A self referencing loop would eventually ring alarm bells with the Salesforce police with the
     * possibility of the Munger being blacklisted
     * An exception is thrown if the stackDepth threshold is reached
     *
     * We cannot simply increment  eda_stackDepth BEFORE calling invoke as a process writer could fuck with this parameter
     * Instead we read and increment eda_stackDepth BEFORE calling invoke using getStackDepth()
     * and assign to an Integer stackDepth variable
     * We use applyStackDepth()  to apply the incremented stackDepth variable to the eda_stackDepth parameter of
     * all messages returned from invoke()
     */
    @TestVisible
    static private Process.PluginResult applyStackDepth(Process.PluginResult results, Integer stackDepth) {
        List<Map<String,Object>> parametersList = new List<Map<String,Object>>();

        Integer count = 0;
        Integer size = results.outputParameters.size();

        for (Integer i = 0; i < size; i++) {
            Object result = results.outputParameters.get(String.valueOf(i));
            String data = System.Json.serialize(result);
            Map<String,Object> parameters = (Map<String,Object>)System.Json.deserializeUntyped(data);
            parameters.put('eda_stackDepth',stackDepth);
            parametersList.add(parameters);
        }

        return EdaUtility.convert(parametersList);
    }

    /**
     * See applyStackDepth() method for context and details.
     */
    @TestVisible
    static private Integer getStackDepth(Map<String,Object> parameters, Integer threshold) {
        Integer stackDepth = (parameters.get('eda_stackDepth') == null) ? 0 : (Integer) parameters.get('eda_stackDepth');
        stackDepth++;
        if (stackDepth > threshold) {
            throw new BrokerException('Maximum Stack Depth exceeded - to resolve, manually set eda_stackDepth on parameters to 0');
        }
        return stackDepth;
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
        Decimal markCount = (Decimal)parameters.get('eda_markCount');
        if (null != markCount) parameters.put('eda_markCount', ++markCount);
        if (2 == markCount) {
            Integer count = parametersList.size();
            parameters.put('eda_count', count);
            if (count == 0) Database.delete(new List<Id>{(Id)parameters.get('eda_gateGroupId')}); //tidy up split of 0
        }
     }
    
    public void restartIfWorkPending() {
        Integer worksPending = [
            SELECT COUNT()
            FROM Message__c
            WHERE Status__c = 'Buffer'
            OR Status__c = 'Reprocess'
        ];
        
        if (worksPending > 0) {
            this.restartImpl();
        }
    }
    
    abstract global Boolean isAlreadyRunning();
     
    abstract global void restartImpl();
    
    @TestVisible public static String getNotificationGuid(Integer size) {
        return EncodingUtil.convertToHex(crypto.generateAesKey(128)).substring(0, size);
    }
}