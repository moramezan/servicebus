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
 * +-----------+ (CONTEXT Q FROM STANDARD USER)
 * |  ENQUEUE  |
 * |  PERSIST  | deals with esb__SequenceName etc
 * +-----------+
 *
 * +-----------+ (CONTEXT F FROM STANDARD USER)
 * |  FUTURE   | calls tooling api with admin sid
 * +-----------+
 *
 * +-----------+ (CONTEXT T AS SYSTEM ADMIN)
 * |TOOLING API| ghosts running user in future
 * +-----------+
 *
 * +-----------+ (CONTEXT S batchable.start AS SYSTEM ADMIN)
 * |  BS HERE  | generate 100 context QueryLocator
 * +-----------+
 *
 * +-----------+ (CONTEXT 1 batchable.execute AS SYSTEM ADMIN)
 * |  MARK     |
 * +-----------+
 *
 * +-----------+ (CONTEXT 2 batchable.execute AS SYSTEM ADMIN)
 * |  EXECUTE  | invokes [Wiretap]
 * |  PERSIST  |
 * +-----------+
 *
 * +-----------+ (CONTEXT 3 batchable.execute AS SYSTEM ADMIN)
 * |  MARK     |
 * +-----------+
 *
 * +-----------+ (CONTEXT 4 batchable.execute AS SYSTEM ADMIN)
 * |  EXECUTE  | invokes [Wiretap]
 * |  PERSIST  |
 * +-----------+
 *
 * +-----------+ (CONTEXT 5 batchable.execute AS SYSTEM ADMIN)
 * |  MARK     |
 * +-----------+
 *
 * +-----------+ (CONTEXT 6 batchable.execute AS SYSTEM ADMIN)
 * |  EXECUTE  | invokes [Terminate]
 * |  PERSIST  |
 * +-----------+
 *
 * +-----------+ (CONTEXT 7 batchable.execute AS SYSTEM ADMIN)
 * |  DONE     | detect exit condition
 * |  ABORTJOB | optionally abort IFF we ran out of work
 * +-----------+
 *
 * +-----------+ (CONTEXT F batchable.finish AS SYSTEM ADMIN)
 * |  RESTART  | optionally restart IFF we exhausted the BS query locator
 * +-----------+
 *
 *
 *
 * As used by a synchronous broker:
 *
 * +-----------+ (CONTEXT 1 FROM SYSTEM ADMIN)
 * |  ENQUEUE  |
 * |  PERSIST  | deals with esb__SequenceName etc
 * |           |
 * |  MARK     |
 * |  EXECUTE  | invokes [Wiretap]
 * |  PERSIST  |
 * |           |
 * |  MARK     |
 * |  EXECUTE  | invokes [Wiretap]
 * |  PERSIST  |
 * |           |
 * |  MARK     |
 * |  EXECUTE  | invokes [Terminate]
 * |  PERSIST  |
 * +-----------+
 */
abstract public with sharing class Broker {
    
    @TestVisible private static Integer MaxHops = 500;
    
    /**
     * #671 first query locator spends less time in 'Preparing'
     */
    static public Boolean IsFirstRun = false;
    
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
    
    static public Broker impl() {
        //first try to resolve broker class from custom setting
        BrokerSetting__c settings = BrokerSetting__c.getInstance();
        
        //if there is no setting, use a default
        if (settings.BrokerClassName__c == null) settings.BrokerClassName__c = Type.forName('VerticalBrokerImplementation').getName(); 
        
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
     * CONTEXT 1:
     * - Locate (lock for update)
     * - Mark   (performs update and puts into stateful, safe from clutches of other jobs)
     *
     * CONTEXT 2:
     * - Locate  (locks totally unrelated next guys)
     * - Execute (reads guys off stateful property, does work and performs update)
     *
     * @return QueryLocator identifying the to-be-marked-as-Started Messages.
     */
    public Database.QueryLocator locateMarkableWork() {
        //find oldest rebuffered message or oldest buffered message
        Message__c specimenMessage;
        try {
            specimenMessage = [
                SELECT Id, Status__c, Route__c
                FROM Message__c
                WHERE Status__c IN ('Rebuffered', 'Buffered')
                ORDER BY Status__c DESC, CreatedDate__c ASC
                LIMIT 1
            ];
        } catch (QueryException e) {
            //no specimen message means no work found, return empty query locator
            return Database.getQueryLocator([SELECT Id FROM Message__c WHERE Id IN (null)]);
        }
        
        //number of times specimen process can run within governor limits
        Integer queryLimit = 1;
        String status = specimenMessage.Status__c;
        String route = specimenMessage.Route__c;
        
        Step__c specimenStep;
        try {
            specimenStep = [
                SELECT Id, Process__r.Limits__c
                FROM Step__c
                WHERE Name = :route
                //LIMIT unnecessary, only one should exist
            ];
            queryLimit = specimenStep.Process__r.Limits__c.intValue();
        } catch (QueryException e) {
            //no step found, resolution problem or might be a heartbeat
        }
        
        Set<Id> messageIds = new Map<Id,Message__c>([
            SELECT Id
            FROM Message__c
            WHERE Status__c = :status
            AND Route__c = :route //chunk by step as opposed to by process
            //ORDER BY CreatedDate__c ASC //not possible when locking
            LIMIT :queryLimit
            FOR UPDATE //#695 investigate broker race condition
        ]).keySet();
        
        //query locator hands back only the messages that are markable as Started
        String commaDelimitedIds = '(\'' + String.join(new List<Id>(messageIds), '\',\'') + '\')';
        String queryString = 'SELECT Id, Route__c, Parameters__c FROM Message__c WHERE Id IN ' + commaDelimitedIds;
        return Database.getQueryLocator(queryString);
    }
    
    /**
     * Sets many Messages statuses to 'Started' and writes them away.
     */
    public List<Database.SaveResult> mark(List<Message__c> messages) {
        try {
            if (!SObjectType.Message__c.Fields.Status__c.Updateable) throw new SalesforceObject.FlsException('!SObjectType.Message__c.Fields.Status__c.Updateable');   
            for (Message__c message : messages) message.Status__c = 'Started';
            return Database.update(messages);
        } catch (Exception e) {
            throw new EngineException(e.getMessage());
        }
    }
    
    /**
     * Resolves and invokes the toStringable Object for one input, handing back an in-memory collection of outputs
     *
     * @param  inputMessages Messages whose status should be Started
     * @return               Many Messages whose status should be Buffered
     */
    public List<Message__c> execute(List<Message__c> inputMessages) {
        //empty inputs, empty outputs
        if (inputMessages.isEmpty()) return new List<Message__c>();
        
        Set<Id> inputMessageIds = new Map<Id,SObject>(inputMessages).keySet();
        
        //OUR FUCKUPS (before invocation)
        
        Map<Id,Map<String,Object>> id2parameters = new Map<Id,Map<String,Object>>();
        for (Message__c inputMessage : inputMessages) id2parameters.put(inputMessage.Id, (Map<String,Object>)Json.deserializeUntyped(inputMessage.Parameters__c));
        
        for (Map<String,Object> parameters : id2parameters.values()) if (!parameters.containsKey('__SequenceName')) throw new Broker.EngineException(null, inputMessageIds, null, 'Mandatory parameter esb__SequenceName not supplied.');
        for (Map<String,Object> parameters : id2parameters.values()) if (!parameters.containsKey('__Position')) throw new Broker.EngineException(null, inputMessageIds, null, 'Mandatory parameter esb__SequenceName not supplied.');
        
        //#575 crow look, go directly to heartbeat process, do not pass go, do not collect $200
        if (id2parameters.get(inputMessages[0].Id).get('__IsHeartbeatProcess') != null) {
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
        Message__c specimen = [SELECT Route__c FROM Message__c WHERE Id = :inputMessages[0].Id];
        
        Step__c step;
        try {
            step = [SELECT ConfigId__c, Process__r.FullyQualifiedClassName__c FROM Step__c WHERE Name = :specimen.Route__c];
        } catch (QueryException e) {
            //this scenario is really following on from a failed resolve - thinking that we might explicitly set a new message status
            //of FAILED but in due course we hope to do away with resolve step entirely with message names '{sequence}#{position}V{version}'
            throw new EngineException(null, inputMessageIds, null, 'Step unqueryable, eg bad sequence name, position, missing terminate.');
        }
        
        Type reflector = Type.forName(step.Process__r.FullyQualifiedClassName__c);
        if (reflector == null) {
            throw new EngineException(null, inputMessageIds, null, 'Reflector for classname was null: ' + step.Process__r.FullyQualifiedClassName__c);
        }
        
        Type meta = Type.forName(step.Process__r.FullyQualifiedClassName__c + '.' + 'ESB');
        if (meta == null) {
            throw new EngineException(null, inputMessageIds, null, 'Could not see ESB inner class, this is not a valid process: ' + reflector.getName());
        }
        
        //save important message properties (such as __Hops) so that process authors cannot pervert them  
        //THROWS EngineException TODO : requires a more generic approach not specific to just the __Hops
        for (Map<String,Object> parameters : id2parameters.values()) if ((Integer)parameters.get('__Hops') >= MaxHops) {
            throw new EngineException(null, inputMessageIds, null, 'Too many hops - to resolve, manually set __Hops on parameters to 0');
        }
        
        //step determines whether all have configs or none
        SObject stepConfig;
        if (step.ConfigId__c != null) {
            //find all steps config ids
            stepConfig = SalesforceObject.getById(step.ConfigId__c);
        }
        
        Map<Id,Broker.Wrapper> id2wrapper = new Map<Id,Broker.Wrapper>();
        for (Message__c inputMessage : inputMessages) id2wrapper.put(inputMessage.Id, new Broker.Wrapper(reflector, id2parameters.get(inputMessage.Id), stepConfig));
        
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
        
        //gate processing support method
        for (Id messageId : id2outputParameters.keySet()) this.gateHelper(id2parameters.get(messageId), id2outputParameters.get(messageId));
        
        //wrap up results into Messages (new guys should have Position = 0)
        List<Message__c> outputMessages = new List<Message__c>();
        for (List<Map<String,Object>> outputParameters : id2outputParameters.values()) for (Map<String,Object> outputParameter : outputParameters) {
            outputMessages.add(new Message__c(
                Parameters__c = Json.serializePretty(outputParameter),
                Status__c = 'Buffered'
            ));
        }
        
        //position + 1
        new MessageObjectSet(outputMessages).incrementPositions();
        
        return outputMessages;
    }

    public List<Database.UpsertResult> persist(List<Message__c> inputMessages, List<Message__c> outputMessages) {
        try {
            for (Message__c message : inputMessages) {
                //designate all input messages as finished
                message.Status__c = 'Completed';
            }
            
            for (Message__c message : outputMessages) {
                //we COULD have designated all output messages as Buffered
                //but it varies if the Broker is paused (they'd be Queued)
            }
            
            //transact both inputs and outputs in one fell swoop
            List<Message__c> messages = new List<Message__c>();
            messages.addAll(inputMessages);
            messages.addAll(outputMessages);
            
            MessageObjectSet.Inhibit = false;
            List<Database.UpsertResult> results = Database.upsert(messages, true); //all or none
            MessageObjectSet.Inhibit = true;
            
            return results;
        } catch (Exception e) {
            Set<Id> messageIds = new Map<Id,Message__c>(inputMessages).keySet();
            throw new EngineException(null, messageIds, e, 'Persist failure.');
        }
    }
    
    /**
     * The Mark helper logic is for the Gate process; it determines when a split occurs, and writes away the number of
     * splitted parameter sets so that a future Gate process can know exactly how many parameter sets form a Gate Group.
     *
     * If markCount isn't null, then the preceding process was a Mark; increment THEN put that value on parameters.
     * If markCount equates to two, then the preceding process was a splitter; write the count of split parameter sets.
     */
    @TestVisible private void gateHelper(Map<String,Object> parameters, List<Map<String,Object>> outputs) {
        Decimal markCount = (Decimal)parameters.get('__MarkCount');
        
        if (null == markCount) {
            //nothing to do, mark process has not tainted the input
            return;
        }
        
        if (outputs.isEmpty()) {
            //nothing to do, split process did not return any outputs, tidy up the gate group
            //Database.delete(new List<Id>{(Id)parameters.get('esb__GateGroupId')});
            return;
        }
        
        markCount++;
        
        for (Map<String,Object> output : outputs) {
            //write markCount onto every output
            output.put('__MarkCount', markCount);
        }
        
        if (1 == markCount) {
            //write outputSize onto every output
            for (Map<String,Object> output : outputs) output.put('__Count', outputs.size());
        }
    }
    
    public void restartIfWorkPending() {
        if (BrokerSetting__c.getInstance().Inhibit__c == true) System.assert(false, 'Inhibit'); //INHIBIT
        
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
    
    static public String getEntryPointGuid(Integer size) {
        return EncodingUtil.convertToHex(crypto.generateAesKey(128)).substring(0, size);
    }
}