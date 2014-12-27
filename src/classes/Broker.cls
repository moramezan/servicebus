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
    
    @TestVisible private static Integer MaxHops  = 500;
    
    public class TooManyHopsException extends Exception {}
      
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
        BrokerSetting__c settings = BrokerSetting__c.getInstance();
        
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
            if(data.startsWith(this.reflector.getName()) && data.endsWith('[]')) 
                throw new EngineException('Your plugin has not overridden the toString() method.' + 
                                          ' Please refer to the Process Developers Guide for specific guidance.');
            
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
     * with 'Rebuffered' and 'Buffered' status).
     *
     * Messages that should be processed have their status marked as Started in the database before being
     * submitted the query locator. That way, if any given execution fails, those messages will remain in the
     * easily identifiable 'Started' state.
     *
     * @return QueryLocator identifying the to-be-marked-as-Started Messages.
     */
    virtual public Database.QueryLocator locateMarkableWork() {
        //find oldest rebuffered message or oldest buffered message
        Message__c specimen;
        try {
            specimen = [
                SELECT Id, Status__c, Process__c, Process__r.Limits__c
                FROM Message__c
                WHERE Status__c IN ('Rebuffered', 'Buffered')
                ORDER BY Status__c DESC, CreatedDate ASC
                LIMIT 1
            ];
        } catch (QueryException e) {
            //no work found, return empty query locator
            return Database.getQueryLocator([SELECT Id FROM Message__c WHERE Id IN (null)]);
        }
        
        //number of times specimen process can run within governor limits, eg 1
        Integer queryLimit = specimen.Process__r.Limits__c != null ? specimen.Process__r.Limits__c.intValue() : 1;
        String status = specimen.Status__c;
        Id processId = specimen.Process__c;
        
        Set<Id> messageIds = new Map<Id,Message__c>([
            SELECT Id
            FROM Message__c
            WHERE Status__c = :status
            ORDER BY CreatedDate ASC
            LIMIT :queryLimit
        ]).keySet();
        
        //query locator hands back only the messages that are markable as Started
        String commaDelimitedIds = '(\'' + String.join(new List<Id>(messageIds), '\',\'') + '\')';
        String queryString = 'SELECT Id, Step__c, Parameters__c, Process__r.FullyQualifiedClassName__c FROM Message__c WHERE Id IN ' + commaDelimitedIds;
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
        //TODO #653
        //if (!SObjectType.Message__c.Createable) throw new Broker.CrudException('!SObjectType.Message__c.Createable'); 
         
        Map<String,Object> injectedParameters = new Map<String,Object> {
            'esb_SequenceName' => sequenceName,
            'Id' => dataId
        };
        
        return enqueue(injectedParameters);  
    }   

    /**
     * Prepares data (represented a parameters collection) for processing.
     * 
     * The parameters collection should at minimum contain 
     *  - an object Id ("Id")
     *  - a sequence name ("esb_SequenceName")
     * Failure to provide these parameters in the parameters collection will throw an EngineException
     * 
     * The parameters collection is converted to a Message object. This Message instance is saved 
     * to the database and the Broker is immeadiately invoked if it is not already running.
     *
     * @param  injectedParameters a parametrised description of the message data.
     */
    static public Id enqueue(Map<String,Object> injectedParameters) {
        //TODO #653
        //if (!SObjectType.Message__c.Createable) throw new Broker.CrudException('!SObjectType.Message__c.Createable');    
        
        // validate params are supplied:
        if (injectedParameters == null) {
            throw new EngineException('Cannot supply a null parameters collection to Broker.enqueue(parameters)');
        }
        
        // validate minimum expected params are supplied:
        List<String> missingParameters = new List<String>();
        Set<String> expectedParameters = new Set<String>{
            'esb_SequenceName',
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
            'esb_EntryPointGuid' => getEntryPointGuid(18),
            'esb_EnqueueUserId' => UserInfo.getUserId(),
            'esb_Position' => 0
        };
      
        // append parameters
           for (String injectedParameter : injectedParameters.keySet()) {
            parameters.put(injectedParameter,injectedParameters.get(injectedParameter));        
        }

        Broker instance = impl();
                
        //create the message destined for the 0th step of the chain
        Message__c message = new Message__c(Parameters__c = Json.serializePretty(parameters));
        
        //fetch the custom setting or create an empty one
        BrokerSetting__c setting = BrokerSetting__c.getOrgDefaults();
        if (setting == null) setting = new BrokerSetting__c();
        
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
        
        Set<Id> inputMessageIds = new Map<Id,SObject>(inputMessages).keySet();
        
        //OUR FUCKUPS (before invocation)
        
        Map<Id,Map<String,Object>> id2parameters = new Map<Id,Map<String,Object>>();
        try {
            for (Message__c inputMessage : inputMessages) id2parameters.put(inputMessage.Id, (Map<String,Object>)Json.deserializeUntyped(inputMessage.Parameters__c));
        } catch (JsonException e) {
            throw new EngineException(null, inputMessageIds, e, 'Could not deserialize json, eg malformed parameters.');
        }
        
        //#575 crow look, go directly to heartbeat process, do not pass go, do not collect $200
        if (id2parameters.get(inputMessages[0].Id).get('esb_IsHeartbeatProcess') != null) {
            //invoke and wrap up results into messages
            List<Message__c> outputMessages = new List<Message__c>();
            for (Message__c inputMessage : inputMessages) {
                Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(inputMessage.Parameters__c);
                List<Map<String,Object>> outputs = new Broker.Wrapper(Heartbeat.class, parameters, null).invokeMain().Outputs;
                for (Map<String,Object> output : outputs) outputMessages.add(new Message__c(Parameters__c = Json.serializePretty(output), Status__c = 'Buffered'));
            }
            return outputMessages;
        }
        
        //specimen message will have same process as others
        Message__c specimen = [SELECT Process__r.FullyQualifiedClassName__c, Step__r.ConfigId__c FROM Message__c WHERE Id = :inputMessages[0].Id];
        
        if (specimen.Step__c == null) {
            //this scenario is really following on from a failed resolve - thinking that we might explicitly set a new message status
            //of FAILED but in due course we hope to do away with resolve step entirely with message names '{sequence}#{position}V{version}'
            throw new EngineException(null, inputMessageIds, null, 'Step unqueryable, eg bad sequence name, position, missing terminate.');
        }
        
        Type reflector = Type.forName(specimen.Process__r.FullyQualifiedClassName__c);
        if (reflector == null) {
            throw new EngineException(null, inputMessageIds, null, 'Reflector for classname was null: ' + specimen.Process__r.FullyQualifiedClassName__c);
        }
        
        Type meta = Type.forName(specimen.Process__r.FullyQualifiedClassName__c + '.' + 'Meta');
        if (meta == null) {
            throw new EngineException(null, inputMessageIds, null, 'Could not see Meta inner class, this is not a valid process: ' + reflector.getName());
        }
        
        //save important message properties (such as esb_Hops) so that process authors cannot pervert them  
        //THROWS EngineException TODO : requires a more generic approach not specific to just the esb_Hops
        Map<Id,Integer> id2hops = new Map<Id,Integer>();
        try {
            for (Message__c inputMessage : inputMessages) id2hops.put(inputMessage.Id, enforceMaxHops(id2parameters.get(inputMessage.Id), maxHops));
        } catch (TooManyHopsException e) {
            //wrapped this here because we need to stick the MESSAGE ID on the exception in order to be able to write the problem away
            throw new EngineException(null, inputMessageIds, e, 'Too many hops - to resolve, manually set esb_Hops on parameters to 0');
        }
        
        //specimen determines whether all have configs or none
        Map<Id,SObject> messageId2config = new Map<Id,SObject>();
        if (specimen.Step__r.ConfigId__c != null) {
            //find all steps config ids
            Map<Id,Message__c> id2message = new Map<Id,Message__c>([
                SELECT Step__r.ConfigId__c
                FROM Message__c
                WHERE Id IN :inputMessageIds
            ]);
            
            //arrange step config ids and query all config sobjects
            List<Id> configIds = new List<Id>();
            for (Message__c message : id2message.values()) configIds.add(message.Step__r.ConfigId__c);
            Map<Id,SObject> configId2config = new Map<Id,SObject>(SalesforceObject.getByIds(configIds));
            
            //arrange config objects against message ids
            for (Message__c message : id2message.values()) messageId2config.put(message.Id, configId2config.get(message.Step__r.ConfigId__c));
        }
        
        Map<Id,Broker.Wrapper> id2wrapper = new Map<Id,Broker.Wrapper>();
        for (Message__c inputMessage : inputMessages) id2wrapper.put(inputMessage.Id, new Broker.Wrapper(reflector, id2parameters.get(inputMessage.Id), messageId2config.get(inputMessage.Id)));
        
        //THEIR FUCKUPS (invocation)
        
        Savepoint sp;
        try {
            
            //TODO COUNT ANY DMLS
            for (Broker.Wrapper wrapper : id2wrapper.values()) wrapper.invokeCallouts();
            sp = Database.setSavepoint();
            for (Broker.Wrapper wrapper : id2wrapper.values()) wrapper.invokeMain();
            //TODO COUNT ANY CALLOUTS
            
        } catch (Exception e) {
            //#581 smoking gun should point at the user, NOT at our broker
            throw new EngineException(sp, inputMessageIds, e);
        }
        
        //OUR FUCKUPS (after invocation)
        
        Map<Id,List<Map<String,Object>>> id2outputParameters = new Map<Id,List<Map<String,Object>>>();
        for (Id messageId : id2wrapper.keySet()) id2outputParameters.put(messageId, id2wrapper.get(messageId).Outputs);
        
        //write back save important message properties to the parameters collections in results
        //TODO : requires a more generic approach to write back the "esb_" properties to 
        for (Id messageId : id2outputParameters.keySet()) this.applyHops(id2outputParameters.get(messageId), id2hops.get(messageId));
        
        //gate processing support method
        for (Id messageId : id2outputParameters.keySet()) this.gateHelper(id2parameters.get(messageId), id2outputParameters.get(messageId));
        
        //wrap up results into Messages
        List<Message__c> outputMessages = new List<Message__c>();
        for (List<Map<String,Object>> outputParameters : id2outputParameters.values()) for (Map<String,Object> outputParameter : outputParameters) {
            outputMessages.add(new Message__c(
                Parameters__c = Json.serializePretty(outputParameter),
                Status__c = 'Buffered'
            ));
        }
        
        return outputMessages;
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
                String sequenceName = (String)parameters.get('esb_SequenceName');
                Decimal position = (Decimal)parameters.get('esb_Position') + 1; //care
                String key = sequenceName + '#' + position;
                key2data.put(key, message);
                
                //increment the position and put it back while we're at it
                parameters.put('esb_Position', position);
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
                if (parameters.get('esb_IsHeartbeatProcess') != null) continue;
                
                String sequenceName = (String)parameters.get('esb_SequenceName');
                Decimal position = (Decimal)parameters.get('esb_Position'); //care
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
     * An exception is thrown if the Max Hops threshold is reached
     *
     * We cannot simply increment  esb_Hops BEFORE calling invoke as a process writer could fuck with this parameter
     * Instead we read and increment esb_Hops BEFORE calling invoke using enforceMaxHops()
     * and assign to an Integer hops variable
     * We use applyHops()  to apply the incremented hops variable to the esb_Hops parameter of
     * all messages returned from invoke()
     */
    @TestVisible List<Map<String,Object>> applyHops(List<Map<String,Object>> results, Integer hops) {
        for (Map<String,Object> result : results) {
            result.put('esb_Hops', hops);
        }
        return results;
    }

    /**
     * See applyHops() method for context and details.
     */
    @TestVisible static private Integer enforceMaxHops(Map<String,Object> parameters, Integer threshold) {
        Integer hops = (parameters.get('esb_Hops') == null) ? 1 : (Integer) parameters.get('esb_Hops');
        hops++;
        if (hops > threshold) {
            throw new TooManyHopsException('Number of hops ' + hops + ' is greater than threshold of ' + threshold);
        }
        return hops;
    }
    
    
    /**
     * The Mark helper logic is for the Gate process; it determines when a split occurs, and writes away the number of
     * splitted parameter sets so that a future Gate process can know exactly how many parameter sets form a Gate Group.
     *
     * If markCount isn't null, then the preceding process was a Mark; increment THEN put that value on parameters.
     * If markCount equates to two, then the preceding process was a splitter; write the count of split parameter sets.
     */
    @TestVisible private void gateHelper(Map<String,Object> parameters, List<Map<String,Object>> outputs) {
        Decimal markCount = (Decimal)parameters.get('esb_MarkCount');
        
        if (null == markCount) {
            //nothing to do, mark process has not tainted the input
            return;
        }
        
        if (outputs.isEmpty()) {
            //nothing to do, split process did not return any outputs, tidy up the gate group
            //Database.delete(new List<Id>{(Id)parameters.get('esb_GateGroupId')});
            return;
        }
        
        markCount++;
        
        for (Map<String,Object> output : outputs) {
            //write markCount onto every output
            output.put('esb_MarkCount', markCount);
        }
        
        if (1 == markCount) {
            //write outputSize onto every output
            for (Map<String,Object> output : outputs) output.put('esb_Count', outputs.size());
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