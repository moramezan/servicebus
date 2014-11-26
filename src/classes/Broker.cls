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
 * |  MARK     | we need to "dirty" these guys with Started status in case they fuck up
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
abstract public with sharing class Broker {
    
    @TestVisible private static Integer stackDepthThreshold  = 500;
    
    public class StackDepthException extends Exception {}
    
    public class EngineException extends Exception {
        /**
         * Gotta jettison this guy for rollback later
         */
        public Savepoint savepoint = null;
        
        /**
         * Persist these guys after rolling back the execute
         */
        public List<Message__c> fuckups = new List<Message__c>();
        
        /**
         * User-error constructor for #581
         * This points the smoking gun at the user process, not our broker.
         *
         * @param savepoint holding any DML to be rolled back by handler
         * @param messageIds which the handler will write away for debug
         * @param userCause of the originating exception due to THEIR code
         */
        public EngineException(Savepoint savepoint, Set<Id> messageIds, Exception userException) {
            this(userException.getMessage(), userException);
            this.savepoint = savepoint;
            for (Id messageId : messageIds) this.fuckups.add(new Message__c(
                Id = messageId,
                Exception__c = userException.getMessage(),
                Cause__c = new ExceptionSerializer(userException).getAsString()
            ));
        }
        
        /**
         * Broker-error constructor for our own fuckups per #598
         *
         * @param savepoint holding any DML to be rolled back by handler
         * @param messageIds which the handler will write away for debug
         * @param brokerCause of the originating exception due to OUR code
         * @param error message that lends detail to what WE did wrong
         */
        public EngineException(Savepoint savepoint, Set<Id> messageIds, Exception brokerException, String message) {
            this(message, brokerException);
            this.savepoint = savepoint;
            for (Id messageId : messageIds) this.fuckups.add(new Message__c(
                Id = messageId,
                Exception__c = this.getMessage(),
                Cause__c = new ExceptionSerializer(this).getAsString()
            ));
        }
    }
    
    /**
     * Usage:
     * new ExceptionSerializer(myEx).getAsString();
     */
    @TestVisible private class ExceptionSerializer {
        
        private JsonGenerator g;
        
        public ExceptionSerializer(Exception e) {
            //true for pretty printing
            g = Json.createGenerator(true);
            
            g.writeStartObject();
            traverseException(e);
            g.writeEndObject();
        }
        
        public String getAsString() {
            return g.getAsString();
        }
        
        @TestVisible private void traverseException(Exception e) {
            //special exceptions
            if (e instanceof DmlException || e instanceof EmailException) {
                Integer n = e.getNumDml();
                g.writeNumberField('NumDml', n);
                
                //the names of the field or fields that caused the error described by the ith failed row
                List<List<String>> dmlFieldNames = new List<List<String>>();
                for (Integer i = 0; i < n; i++) dmlFieldNames.add(e.getDmlFieldNames(i));
                g.writeObjectField('DmlFieldNames', dmlFieldNames);
                
                //cannot serialize Schema.sObjectField
                //List<List<Schema.sObjectField>> dmlFields = new List<List<Schema.sObjectField>>();
                //for (Integer i = 0; i < n; i++) dmlFields.add(e.getDmlFields(i));
                //g.writeObjectField('DmlFields', dmlFields); 
                
                //the ID of the failed record that caused the error described by the ith failed row
                List<Id> dmlIds = new List<Id>();
                for (Integer i = 0; i < n; i++) dmlIds.add(e.getDmlId(i));
                g.writeObjectField('DmlIds', dmlIds);
                
                //the original row position of the ith failed row
                List<Integer> dmlIndexes = new List<Integer>();
                for (Integer i = 0; i < n; i++) dmlIndexes.add(e.getDmlIndex(i));
                g.writeObjectField('DmlIndexes', dmlIndexes);
                
                //the user message for the ith failed row
                List<String> dmlMessages = new List<String>();
                for (Integer i = 0; i < n; i++) dmlMessages.add(e.getDmlMessage(i));
                g.writeObjectField('DmlMessages', dmlMessages);
                
                //the Apex failure code for the ith failed row
                List<String> dmlStatusCodes = new List<String>();
                for (Integer i = 0; i < n; i++) dmlStatusCodes.add(e.getDmlStatusCode(i));
                g.writeObjectField('DmlStatusCodes', dmlStatusCodes);
                
                //cannot serialize Enum
                //List<System.StatusCode> dmlTypes = new List<System.StatusCode>();
                //for (Integer i = 0; i < n; i++) dmlTypes.add(e.getDmlType(i));
                //g.writeObjectField('DmlTpes', dmlTypes);
            }
            
            //normal exceptions
            g.writeNumberField('LineNumber', e.getLineNumber());
            g.writeStringField('Message', e.getMessage());
            g.writeStringField('StackTraceString', e.getStackTraceString());
            g.writeStringField('TypeName', e.getTypeName());
            g.writeFieldName('Cause');
            
            if (e.getCause() == null) {
                //time to stop recursing
                this.g.writeNull();
                return;
            }
            
            //recurse into causes
            g.writeStartObject();
            traverseException(e.getCause());
            g.writeEndObject();
        }
        
    }
    
    public class CrudException extends Exception {}
    
    public class FlsException extends Exception {}
    
    static public Broker impl() {
        //first try to resolve broker class from custom setting
        BrokerSettings__c settings = BrokerSettings__c.getInstance();
        
        //if there is no setting, use a default
        if (settings.BrokerClassName__c == null) settings.BrokerClassName__c = VerticalBrokerImplementation.class.getName(); 
        
        //new up and return the broker instance
        Broker impl = (Broker)Type.forName(settings.BrokerClassName__c).newInstance();
        return impl;
    }
    
    /**
     * Example usage:
     * Broker.Wrapper wrapper = new Broker.Wrapper(reflector, parameters, config);
     * wrapper.invokeCallouts();
     * wrapper.invokeMain();
     * List<Map<String,Object>> outputs = wrapper.Outputs;
     */
    @TestVisible private class Wrapper {
        /**
         * We need to know "what" the plugin is
         * whenever we get or set its properties as
         * deserialize requires a concrete type.
         */
        private Type reflector;
        
        /**
         * Must "hang on to" the plugin instance so it
         * can be invoked twice and communicate with
         * itself across invocations.
         */
        private Object plugin;
        
        /**
         * The config instance must be available in
         * both callouts and invocation contexts.
         */
        private SObject config;
        
        /**
         * The input parameters are used twice. For
         * assembling the plugin before invocation
         * AND for balance + delta jiggery pokery.
         */
        private Map<String,Object> Inputs;
        
        /**
         * The output collection can only be made by
         * invoking the main plugin logic, save them here
         * so they're available wherever wrapper scope is.
         */
        public List<Map<String,Object>> Outputs;
        
        /**
         * @param reflector from the concrete plugin type eg Branch.class
         * @param parameters that will be handed in when invoking plugin
         * @param config that optionally lives on the step
         */
        public Wrapper(Type reflector, Map<String,Object> inputs, SObject config) {
            this.reflector = reflector;
            this.inputs = inputs;
            this.config = config;
            
            Map<String,Object> untyped = new Map<String,Object>{
                'Parameters' => Json.serialize(inputs),
                'StepConfig' => this.config
            };
            
            //do not call constructor
            //this.plugin = reflector.newInstance();
            this.plugin = Json.deserialize(Json.serialize(untyped), reflector);
        }
        
        /**
         * @throws EngineException
         * @return fluent API
         */
        public Wrapper invokeCallouts() {
            if (!(this.plugin instanceof Database.AllowsCallouts)) {
                //nothing to do
                return this;
            }
            
            //set flag
            Map<String,Object> untyped = (Map<String,Object>)Json.deserializeUntyped(Json.serialize(this.plugin));
            untyped.put('AllowsCallouts', true);
            this.plugin = Json.deserialize(Json.serialize(untyped), this.reflector);
            
            //do callouts
            String data = String.valueOf(this.plugin);
            if (data != null) throw new EngineException('Your AllowsCallouts code block should return null.');
            
            return this;
        }
        
        /**
         * @throws EngineException
         * @return fluent API
         */
        public Wrapper invokeMain() {
            //set flag
            Map<String,Object> untyped = (Map<String,Object>)Json.deserializeUntyped(Json.serialize(this.plugin));
            untyped.put('AllowsCallouts', false);
            this.plugin = Json.deserialize(Json.serialize(untyped), this.reflector);
            
            //do invocation
            String data = String.valueOf(this.plugin);
            if (data == null) throw new EngineException('Your main code block should return a serialized List<Map<String,Object>>.');
            
            //output equals balance plus delta
            List<Map<String,Object>> outputs = new List<Map<String,Object>>();
            List<Object> results = (List<Object>)Json.deserializeUntyped(data);
            for (Object result : results) {
                Map<String,Object> output = this.inputs.clone();
                output.putAll((Map<String,Object>)result);
                outputs.add(output);
            }
            
            this.outputs = outputs;
            
            return this;
        }
    }

    /**
     * Determines which messages are eligible to be moved into the Started status (by finding Messages
     * with 'Rebuffered' and 'Buffered' status). Note: too many fucked messages would clog up the system,
     * so we have a system-wide fuckedLimit.
     *
     * Messages that should be processed have their status marked as Started in the database before being
     * submitted the query locator. That way, if any given execution fails, those messages will remain in the
     * easily identifiable 'Started' state.
     *
     * @param workCount Maximum number of Messages to mark and locate (subject to fuckups)
     * @return          Query Locator identifying the now-marked-as-Started Messages.
     */
    virtual public Database.QueryLocator locateMarkableWork(Integer workCount) {
        Integer fuckedLimit = 100;
        
        Integer fuckedCount = [
            SELECT COUNT()
            FROM Message__c
            WHERE Status__c = 'Started'
        ];
        
        Integer rebufferedCount = [
            SELECT COUNT()
            FROM Message__c
            WHERE Status__c = 'Rebuffered'
        ];
        
        //derives maximum number of Messages available for starting
        Integer queryLimit = Math.max(0, fuckedLimit - fuckedCount) + rebufferedCount;
        
        Set<Id> messageIds = new Map<Id,Message__c>([
            SELECT Id
            FROM Message__c
            WHERE Status__c IN ('Rebuffered', 'Buffered')
            ORDER BY Status__c DESC
            LIMIT :Math.min(workCount, queryLimit)
        ]).keySet();
        
        //query locator hands back only the messages that are markable as Started
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
    static public Id enqueue(String sequenceName, Id dataId) {
        if (!SObjectType.Message__c.Createable) throw new Broker.CrudException('!SObjectType.Message__c.Createable'); 
         
        Map<String,Object> injectedParameters = new Map<String,Object> {
            'eda_SequenceName' => sequenceName,
            'Id' => dataId
        };
        
        return enqueue(injectedParameters);  
    }   

    /**
     * Prepares data (represented a parameters collection) for processing.
     * 
     * The parameters collection should at minimum contain 
     *  - an object Id ("Id")
     *  - a sequence name ("eda_SequenceName")
     * Failure to provide these parameters in the parameters collection will throw an EngineException
     * 
     * The parameters collection is converted to a Message object. This Message instance is saved 
     * to the database and the Broker is immeadiately invoked if it is not already running.
     *
     * @param  injectedParameters a parametrised description of the message data.
     */
    static public Id enqueue(Map<String,Object> injectedParameters) {
        if (!SObjectType.Message__c.Createable) throw new Broker.CrudException('!SObjectType.Message__c.Createable');    
        
        
        // validate params are supplied:
        if (injectedParameters == null) {
            throw new EngineException('Cannot supply a null parameters collection to Broker.enqueue(parameters)');
        }
        
        // validate minimum expected params are supplied:
        List<String> missingParameters = new List<String>();
        Set<String> expectedParameters = new Set<String>{
            'eda_SequenceName',
            'Id'     
        };
        for (String expectedParameter : expectedParameters) {
            if(!injectedParameters.keySet().contains(expectedParameter)) 
                missingParameters.add(expectedParameter);   
        }
        if (missingParameters.size() > 0) {
            throw new EngineException(
                'The following mandatory parameters were not supplied to Broker.enqueue() [' +
                String.join(missingParameters,',') + 
                ']'
            );
        }

        Map<String,Object> parameters = new Map<String,Object> {
            'eda_EntryPointGuid' => getEntryPointGuid(18),
            'eda_EnqueueUserId' => UserInfo.getUserId(),
            'eda_Position' => 0
        };
      
        // append parameters
           for (String injectedParameter : injectedParameters.keySet()) {
            parameters.put(injectedParameter,injectedParameters.get(injectedParameter));        
        }

        Broker instance = impl();
                
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
            message.Status__c = 'Buffered';
            instance.resolve(new List<Message__c>{message}); //RESOLVE
        }
        
        upsert message;
        Broker.process();
        return message.Id;
    }
    
    /**
     * //TODO
     * //If we are scheduled, use the default batch broker which doesn't need a session id (unlike futurebroker)
     * //if (System.isScheduled()) settings.BrokerClassName__c = VerticalBrokerImplementation.class.getName();
     */
    static public void process() {
        Broker impl = impl();
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
    static public Id enqueue(String sequenceName, Blob data) {
        if (!SObjectType.Document.Createable) throw new Broker.CrudException('!SObjectType.Document.Createable');
            
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
        return enqueue(sequenceName, document.Id);
    }
    
    /**
     * Sets many Messages statuses to 'Started' and writes them away.
     */
    virtual public List<Database.SaveResult> mark(List<Message__c> messages) {
        try {
            if (!SObjectType.Message__c.Fields.Status__c.Updateable) throw new Broker.FlsException('!SObjectType.Message__c.Fields.Status__c.Updateable');   
            for (Message__c message : messages) message.Status__c = 'Started';
            return Database.update(messages);
        } catch (Exception e) {
            throw new EngineException('Mark failure!', e);
        }
    }
    
    /**
     * Resolves and invokes the toStringable Object for one input, handing back an in-memory collection of outputs
     *
     * @param  inputMessages Messages whose status should be Started
     * @return               Many Messages whose status should be Buffered
     */
    virtual public List<Message__c> execute(List<Message__c> inputMessages) {
        //empty inputs, empty outputs
        if (inputMessages.isEmpty()) return new List<Message__c>();
        
        Message__c message = inputMessages[0]; //TODO chunking
        
        //OUR FUCKUPS (before invocation)
        
        Map<String,Object> parameters;
        try {
            parameters = (Map<String,Object>)Json.deserializeUntyped(message.Parameters__c);
        } catch (JsonException e) {
            throw new EngineException(null, new Set<Id>{message.Id}, e, 'Could not deserialize json, eg malformed parameters.');
        }
        
        //#575 crow look, go directly to heartbeat process, do not pass go, do not collect $200
        if (parameters.get('eda_IsHeartbeatProcess') != null) {
            //invoke and wrap up results into messages
            List<Map<String,Object>> outputs = new Broker.Wrapper(Heartbeat.class, parameters, null).invokeMain().Outputs;
            List<Message__c> messages = new List<Message__c>();
            for (Object output : outputs) messages.add(new Message__c(Parameters__c = Json.serializePretty(output), Status__c = 'Buffered'));
            return messages;
        }
        
        Step__c step;
        try {
            step = [
                SELECT Process__c, ConfigId__c, Process__r.Name, Process__r.FullyQualifiedClassName__c
                FROM Step__c
                WHERE Id = :message.Step__c
            ];
        } catch (QueryException e) {
            throw new EngineException(null, new Set<Id>{message.Id}, e, 'Step unqueryable, eg bad sequence name, position, missing terminate.');
        }
        
        Type reflector = Type.forName(step.Process__r.FullyQualifiedClassName__c);
        if (reflector == null) {
            throw new EngineException(null, new Set<Id>{message.Id}, null, 'Reflector for classname was null: ' + step.Process__r.FullyQualifiedClassName__c);
        }
        
        Type meta = Type.forName(step.Process__r.FullyQualifiedClassName__c + '.' + 'Meta');
        if (meta == null) {
            throw new EngineException(null, new Set<Id>{message.Id}, null, 'Could not see Meta inner class, this is not a valid process: ' + reflector.getName());
        }
        
        //save important message properties (such as stackDepth) so that process authors cannot pervert them  
        //THROWS EngineException TODO : requires a more generic approach not specific to just the eda_StackDepth
        Integer stackDepth;
        try {
            stackDepth = enforceStackDepth(parameters, stackDepthThreshold);
        } catch (StackDepthException e) {
            //wrapped this here because we need to stick the MESSAGE ID on the exception in order to be able to write the problem away
            throw new EngineException(null, new Set<Id>{message.Id}, e, 'Maximum Stack Depth exceeded - to resolve, manually set eda_StackDepth on parameters to 0');
        }
        
        SObject config;
        if (step.ConfigId__c != null) config = SalesforceObject.getById(step.ConfigId__c);
        Broker.Wrapper wrapper = new Broker.Wrapper(reflector, parameters, config);
        
        //THEIR FUCKUPS (invocation)
        
        Savepoint sp;
        try {
            
            //TODO COUNT ANY DMLS
            wrapper.invokeCallouts();
            sp = Database.setSavepoint();
            wrapper.invokeMain();
            //TODO COUNT ANY CALLOUTS
            
        } catch (Exception e) {
            //#581 smoking gun should point at the user, NOT at our broker
            throw new EngineException(sp, new Set<Id>{message.Id}, e);
        }
        
        //OUR FUCKUPS  (after invocation)
        
        List<Map<String,Object>> results = wrapper.Outputs;
        
        //write back save important message properties to the parameters collections in results
        //TODO : requires a more generic approach to write back the "eda_" properties to 
        this.applyStackDepth(results, stackDepth);

        //gate processing support method
        this.gateHelper(parameters, results);
        
        //wrap up results into Messages
        List<Message__c> messages = new List<Message__c>();
        for (Map<String,Object> n : results) {
            messages.add(new Message__c(
                Parameters__c = Json.serializePretty(n),
                Status__c = 'Buffered'
            ));
        }
        
        return messages;
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
    virtual public void resolve(List<Message__c> messages) {
        Set<Id> fuckedIds = new Set<Id>();
        Exception firstError;
        
        //assemble a map of next-step keys to messages
        Map<String,Message__c> key2data = new Map<String,Message__c>();
        for (Message__c message : messages) {
            try {
                Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(message.Parameters__c);
                String sequenceName = (String)parameters.get('eda_SequenceName');
                Decimal position = (Decimal)parameters.get('eda_Position') + 1; //care
                String key = sequenceName + '#' + position;
                key2data.put(key, message);
                
                //increment the position and put it back while we're at it
                parameters.put('eda_Position', position);
                message.Parameters__c = Json.serializePretty(parameters);
            } catch (Exception e) {
                firstError = e;
                fuckedIds.add(message.Id);
            }
        }
        
        //resolve the next steps and processes
        List<Step__c> steps = [
            SELECT Id, Name, Process__r.Id, Sequence__r.Id
            FROM Step__c
            WHERE Name IN :key2data.keySet()
        ];
        
        //assemble a map of next-step keys to steps
        Map<String,Step__c> key2step = new Map<String,Step__c>();
        for (Step__c step : steps) key2step.put(step.Name, step);
        
        //now put the resolved sequence/step/process on each message
        for (Message__c message : messages) {
            try {
                Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(message.Parameters__c);
                
                //#575 crow look, heartbeat doesn't need his sequence or step resolved
                if (parameters.get('eda_IsHeartbeatProcess') != null) continue;
                
                String sequenceName = (String)parameters.get('eda_SequenceName');
                Decimal position = (Decimal)parameters.get('eda_Position'); //care
                String key = sequenceName + '#' + position;
                
                Step__c step = key2step.get(key);
                message.Sequence__c = step.Sequence__r.Id;
                message.Process__c = step.Process__r.Id;
                message.Step__c = step.Id;
            } catch (Exception e) {
                firstError = e;
                fuckedIds.add(message.Id);
            }
        }
        
        //DML time!
        upsert messages;
        
        if (!fuckedIds.isEmpty()) throw new EngineException(null, fuckedIds, firstError, 'Resolve failure, check sequence config.');
    }
    
    virtual public List<Database.UpsertResult> persist(List<Message__c> inputMessages, List<Message__c> outputMessages) {
        try {
            for (Message__c message : inputMessages) {
                //designate all input messages as finished
                message.Status__c = 'Completed';
            }
            
            //transact both inputs and outputs in one fell swoop
            List<Message__c> messages = new List<Message__c>();
            messages.addAll(inputMessages);
            messages.addAll(outputMessages);
            return Database.upsert(messages, true); //all or none
        } catch (Exception e) {
            Set<Id> messageIds = new Map<Id,Message__c>(inputMessages).keySet();
            throw new EngineException(null, messageIds, e, 'Persist failure.');
        }
    }
    
     /**
     * Context:
     * A message can pass through a limited number of steps. This "limit" is a fairly high arbitrary threshold.
     * The intent is to prevent a never ending self referencing loop (we cannot control what the system configurators
     * configure). A self referencing loop would eventually ring alarm bells with the Salesforce police with the
     * possibility of the Munger being blacklisted
     * An exception is thrown if the stackDepth threshold is reached
     *
     * We cannot simply increment  eda_StackDepth BEFORE calling invoke as a process writer could fuck with this parameter
     * Instead we read and increment eda_StackDepth BEFORE calling invoke using enforceStackDepth()
     * and assign to an Integer stackDepth variable
     * We use applyStackDepth()  to apply the incremented stackDepth variable to the eda_StackDepth parameter of
     * all messages returned from invoke()
     */
    @TestVisible List<Map<String,Object>> applyStackDepth(List<Map<String,Object>> results, Integer stackDepth) {
        for (Map<String,Object> result : results) {
            result.put('eda_StackDepth',stackDepth);
        }
        return results;
    }

    /**
     * See applyStackDepth() method for context and details.
     */
    @TestVisible static private Integer enforceStackDepth(Map<String,Object> parameters, Integer threshold) {
        Integer stackDepth = (parameters.get('eda_StackDepth') == null) ? 0 : (Integer) parameters.get('eda_StackDepth');
        stackDepth++;
        if (stackDepth > threshold) {
            throw new StackDepthException('Stack depth of ' + stackDepth + ' is greater than threshold of ' + threshold);
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
    @TestVisible private void gateHelper(Map<String,Object> parameters, List<Map<String,Object>> outputs) {
        Decimal markCount = (Decimal)parameters.get('eda_MarkCount');
        
        if (null == markCount) {
            //nothing to do, mark process has not tainted the input
            return;
        }
        
        if (outputs.isEmpty()) {
            //nothing to do, split process did not return any outputs, tidy up the gate group
            //Database.delete(new List<Id>{(Id)parameters.get('eda_GateGroupId')});
            return;
        }
        
        markCount++;
        
        for (Map<String,Object> output : outputs) {
            //write markCount onto every output
            output.put('eda_MarkCount', markCount);
        }
        
        if (2 == markCount) {
            //write outputSize onto every output
            for (Map<String,Object> output : outputs) output.put('eda_Count', outputs.size());
        }
    }
    
    public void restartIfWorkPending() {
        Integer worksPending = [
            SELECT COUNT()
            FROM Message__c
            WHERE Status__c = 'Buffered'
            OR Status__c = 'Rebuffered'
        ];
        
        if (worksPending > 0) {
            this.restartImpl();
        }
    }
    
    abstract public Boolean isAlreadyRunning();
     
    abstract public void restartImpl();
    
    @TestVisible static private String getEntryPointGuid(Integer size) {
        return EncodingUtil.convertToHex(crypto.generateAesKey(128)).substring(0, size);
    }
}