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
                Exception__c = userException.getMessage().abbreviate(SObjectType.Message__c.Fields.Exception__c.Length), //#754
                Cause__c = new ExceptionSerializer(userException).getAsString().abbreviate(SObjectType.Message__c.Fields.Cause__c.Length) //#754
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
                Exception__c = this.getMessage().abbreviate(SObjectType.Message__c.Fields.Exception__c.Length), //#754
                Cause__c = new ExceptionSerializer(this).getAsString().abbreviate(SObjectType.Message__c.Fields.Cause__c.Length) //#754
            ));
        }
    }
    
    /**
     * Usage:
     * new ExceptionSerializer(myEx).getAsString();
     */
    public class ExceptionSerializer {
        
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
     * Broker.Wrapper wrapper = new Broker.Wrapper(reflector, parameters);
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
         * The input event gets used twice. For
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

        public String SessionId;

        /**
         * @param reflector from the concrete plugin type eg Branch.class
         * @param input event that will be handed in when invoking plugin
         */
        public Wrapper(Type reflector, Map<String,Object> inputs) {
            this.reflector = reflector;
            this.inputs = inputs;
            
            Map<String,Object> untyped = new Map<String,Object>{
                'Event' => Json.serialize(inputs)
            };
            
            // Surface SessionId to select few orgs and packages
            String sessionId = (OAuthSetting__c.getInstance()).AccessToken__c;
            Boolean allowSessionId = isAllowedSessionId(reflector.getName(), UserInfo.getOrganizationId());
            if (allowSessionId) untyped.put('SessionId',sessionId);
   
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
            this.Inputs.put('esb__AllowsCallouts', true);
            untyped.put('Event', Json.serialize(this.Inputs));
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
            this.Inputs.put('esb__AllowsCallouts', false);
            untyped.put('Event', Json.serialize(this.Inputs));
            this.plugin = Json.deserialize(Json.serialize(untyped), this.reflector);
            
            //do invocation
            String data = String.valueOf(this.plugin);
            if (data == null) throw new EngineException('Your main code block should return a serialized List<Map<String,Object>>.');
            if(data.endsWith(this.reflector.getName().replaceAll('[^.]+\\.', '') + ':[]'))
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
     * with 'Buffered' status).
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
     * @return collection of soon-to-be-marked-as-Started Messages.
     */
    public List<Message__c> locateMarkableWork() {
        //find oldest buffered message
        Message__c specimenMessage;
        try {
            specimenMessage = [
                SELECT Id, Status__c, Route__c, Attempts__c
                FROM Message__c
                WHERE Status__c = 'Buffered'
                ORDER BY Attempts__c DESC, CreatedDate__c ASC //TODO could sort by route
                LIMIT 1
            ];
        } catch (QueryException e) {
            //no specimen message means no work found, return empty query locator
            return [SELECT Id FROM Message__c WHERE Id IN (null)];
        }
        
        //number of times specimen process can run within governor limits
        Integer queryLimit = 1;
        String className = null; //#697
        String status = specimenMessage.Status__c;
        String route = specimenMessage.Route__c;
        
        Step__c specimenStep;
        try {
            specimenStep = [
                SELECT Id, Process__r.Limits__c, Process__r.FullyQualifiedClassName__c
                FROM Step__c
                WHERE Name = :route
                //LIMIT unnecessary, only one should exist
            ];
            className = specimenStep.Process__r.FullyQualifiedClassName__c;
            queryLimit = specimenStep.Process__r.Limits__c.intValue();
        } catch (QueryException e) {
            //no step found, resolution problem or might be a heartbeat
        }
        
        List<Message__c> messages = [
            SELECT Id, Route__c, Event__c
            FROM Message__c
            WHERE Status__c = :status
            AND Route__c = :route //chunk by step as opposed to by process
            //ORDER BY CreatedDate__c ASC //not possible when locking
            LIMIT :queryLimit
            FOR UPDATE //#695 investigate broker race condition
        ];
        
        //#697 let these guys get written away to make monitoring simpler (crow look)
        for (Message__c message : messages) message.FullyQualifiedClassName__c = className;
        
        return messages;
    }
    
    /**
     * Sets many Messages statuses to 'Started' and writes them away.
     */
    public List<Database.SaveResult> mark(List<Message__c> messages) {
        try {
            if (!SObjectType.Message__c.Fields.Status__c.Updateable) throw new ApexDomain.FlsException('!SObjectType.Message__c.Fields.Status__c.Updateable');
            for (Message__c message : messages) {
                if (message.Attempts__c == null) message.Attempts__c = 0;
                message.Attempts__c++; //#808
                message.Status__c = 'Started'; //in-database
            }
            List<Database.SaveResult> results = Database.update(messages);
            return results;
            
        } catch (Exception e) {
            throw new EngineException('Mark exception', e);
        }
    }
    
    /**
     * Resolves and invokes the toStringable Object for one input, handing back an in-memory collection of outputs
     *
     * @throws EngineException
     * @param  inputMessages pass-by-reference Messages whose status should be Started
     * @param  outputMessages pass-by-reference Messages whose status should be Started
     */
    public void execute(List<Message__c> inputMessages, List<Message__c> outputMessages) {
        //empty inputs, empty outputs
        //if (inputMessages.isEmpty()) return new List<Message__c>();
        if (inputMessages.isEmpty()) return;
        
        //Set<Id> inputMessageIds = new Map<Id,SObject>(inputMessages).keySet();
        Integer chunkTotal = inputMessages.size();
        Integer chunk = 1;
        for (Message__c inputMessage :  inputMessages) {
            Map<String,Object> inputEvent = (Map<String,Object>)Json.deserializeUntyped(inputMessage.Event__c);
            inputEvent.put('__ChunkTotal', chunkTotal);
            inputEvent.put('__Chunk', chunk);
            inputMessage.Event__c = Json.serializePretty(inputEvent);
            chunk++;
        }
        
        //OUR FUCKUPS (before invocation)
        Boolean biggerProblems = false;
        Map<Id,Map<String,Object>> id2events = new Map<Id,Map<String,Object>>();
        Map<Id,DateTime> idToStartStamp = new Map<Id,DateTime>();
        for (Message__c inputMessage : inputMessages) {
            DateTime startStamp = System.Now();
            idToStartStamp.put(inputMessage.Id, startStamp);

            Map<String,Object> inputEvent = (Map<String,Object>)Json.deserializeUntyped(inputMessage.Event__c);
            id2events.put(inputMessage.Id, inputEvent);

            if (!inputEvent.containsKey('__SequenceName')) {
                biggerProblems = true;
                Exception e = new Broker.EngineException('Mandatory event parameter esb__SequenceName not supplied.');
                inputMessage.Exception__c = e.getMessage().abbreviate(SObjectType.Message__c.Fields.Exception__c.Length);
                inputMessage.Cause__c = new ExceptionSerializer(e).getAsString().abbreviate(SObjectType.Message__c.Fields.Cause__c.Length);
                inputMessage.ExecuteDuration__c = System.Now().getTime() - startStamp.getTime();
            }
            
            if (!inputEvent.containsKey('__Position')) {
                biggerProblems = true;
                Exception e = new Broker.EngineException('Mandatory event parameter esb__SequenceName not supplied.');
                inputMessage.Exception__c = e.getMessage().abbreviate(SObjectType.Message__c.Fields.Exception__c.Length);
                inputMessage.Cause__c = new ExceptionSerializer(e).getAsString().abbreviate(SObjectType.Message__c.Fields.Cause__c.Length);
                inputMessage.ExecuteDuration__c = System.Now().getTime() - startStamp.getTime();
            }
        }
        
        if (biggerProblems) return;
        
        //#575 crow look, go directly to heartbeat process, do not pass go, do not collect $200
        if (id2events.get(inputMessages[0].Id).get('__IsHeartbeatProcess') != null) {
            //invoke and wrap up results into messages
            for (Message__c inputMessage : inputMessages) {
                DateTime startStamp = idToStartStamp.get(inputMessage.Id);

                Map<String,Object> inputEvent = (Map<String,Object>)Json.deserializeUntyped(inputMessage.Event__c);
                List<Map<String,Object>> outputs = new Broker.Wrapper(Heartbeat.class, inputEvent).invokeMain().Outputs;
                
                inputMessage.Status__c = 'Completed'; //#798
                inputMessage.Exception__c = null;
                inputMessage.Cause__c = null;
                inputMessage.FullyQualifiedClassName__c = Heartbeat.class.getName(); //#697 locateMarkableWork misses this for heartbeats
                
                for (Map<String,Object> output : outputs) outputMessages.add(new Message__c(Event__c = Json.serializePretty(output), Status__c = 'Buffered'));

                inputMessage.ExecuteDuration__c = System.Now().getTime() - startStamp.getTime();
            }
            return;
        }
        
        //specimen message will have same process as others
        Message__c specimen = [SELECT Route__c FROM Message__c WHERE Id = :inputMessages[0].Id];

        Step__c step;
        try {
            step = [SELECT ConfigId__c, Process__r.FullyQualifiedClassName__c FROM Step__c WHERE Name = :specimen.Route__c];
        } catch (QueryException qe) {
            //this scenario is really following on from a failed resolve - thinking that we might explicitly set a new message status
            //of FAILED but in due course we hope to do away with resolve step entirely with message names '{sequence}#{position}V{version}'
            for (Message__c inputMessage : inputMessages) {
                DateTime startStamp = idToStartStamp.get(inputMessage.Id);
                Exception e = new Broker.EngineException('Step unqueryable, eg bad sequence name, position, missing terminate.', qe);
                inputMessage.Exception__c = e.getMessage().abbreviate(SObjectType.Message__c.Fields.Exception__c.Length);
                inputMessage.Cause__c = new ExceptionSerializer(e).getAsString().abbreviate(SObjectType.Message__c.Fields.Cause__c.Length);
                inputMessage.ExecuteDuration__c = System.Now().getTime() - startStamp.getTime();
            }
            return;
        }
        
        Type reflector = Type.forName(step.Process__r.FullyQualifiedClassName__c);
        if (reflector == null) {
            for (Message__c inputMessage : inputMessages) {
                DateTime startStamp = idToStartStamp.get(inputMessage.Id);
                Exception e = new Broker.EngineException('Reflector for classname was null: ' + step.Process__r.FullyQualifiedClassName__c);
                inputMessage.Exception__c = e.getMessage().abbreviate(SObjectType.Message__c.Fields.Exception__c.Length);
                inputMessage.Cause__c = new ExceptionSerializer(e).getAsString().abbreviate(SObjectType.Message__c.Fields.Cause__c.Length);
                inputMessage.ExecuteDuration__c = System.Now().getTime() - startStamp.getTime();
            }
            return;
        }
        
        Type meta = Type.forName(step.Process__r.FullyQualifiedClassName__c + '.' + 'ESB');
        if (meta == null) meta = Type.forName(step.Process__r.FullyQualifiedClassName__c + 'ESB'); //#828
        if (meta == null) {
            for (Message__c inputMessage : inputMessages) {
                DateTime startStamp = idToStartStamp.get(inputMessage.Id);
                Exception e = new Broker.EngineException('Could not see ESB inner class, this is not a valid process: ' + reflector.getName());
                inputMessage.Exception__c = e.getMessage().abbreviate(SObjectType.Message__c.Fields.Exception__c.Length);
                inputMessage.Cause__c = new ExceptionSerializer(e).getAsString().abbreviate(SObjectType.Message__c.Fields.Cause__c.Length);
                inputMessage.ExecuteDuration__c = System.Now().getTime() - startStamp.getTime();
            }
            return;
        }
        
        //save important message properties (such as __Hops) so that process authors cannot pervert them
        //THROWS EngineException TODO : requires a more generic approach not specific to just the __Hops
        for (Message__c inputMessage : inputMessages) {
            DateTime startStamp = idToStartStamp.get(inputMessage.Id);
            Map<String,Object> inputEvent = (Map<String,Object>)Json.deserializeUntyped(inputMessage.Event__c);
            if ((Integer)inputEvent.get('__Hops') >= MaxHops) {
                biggerProblems = true;
                Exception e = new Broker.EngineException('Too many hops - to resolve, manually set __Hops on event parameters to 0');
                inputMessage.Exception__c = e.getMessage().abbreviate(SObjectType.Message__c.Fields.Exception__c.Length);
                inputMessage.Cause__c = new ExceptionSerializer(e).getAsString().abbreviate(SObjectType.Message__c.Fields.Cause__c.Length);
                inputMessage.ExecuteDuration__c = System.Now().getTime() - startStamp.getTime();
            }
        }
        
        if (biggerProblems) return;
        
        //step determines whether all have configs or none
        SObject stepConfig;
        if (step.ConfigId__c != null) {
            //find all steps config ids
            stepConfig = ApexDomain.getById(step.ConfigId__c);
            
            for (Message__c inputMessage : inputMessages) {
                Map<String,Object> inputEvent = (Map<String,Object>)Json.deserializeUntyped(inputMessage.Event__c);
                inputEvent.put('esb__StepConfig', stepConfig);
                inputMessage.Event__c = Json.serialize(inputEvent);
            }
        } else {
            for (Message__c inputMessage : inputMessages) {
                Map<String,Object> inputEvent = (Map<String,Object>)Json.deserializeUntyped(inputMessage.Event__c);
                inputEvent.put('esb__StepConfig', null);
                inputMessage.Event__c = Json.serialize(inputEvent);
            }
        }
        
        List<Broker.Wrapper> wrappers = new List<Broker.Wrapper>();
        for (Message__c inputMessage : inputMessages) wrappers.add(new Broker.Wrapper(reflector, id2events.get(inputMessage.Id)));
        
        //THEIR FUCKUPS (invocation)
        
        for (Integer i = 0; i < inputMessages.size(); i++) {
            Message__c inputMessage = inputMessages[i];
            DateTime startStamp = idToStartStamp.get(inputMessage.Id);

            //TODO COUNT ANY DMLS
            Broker.Wrapper wrapper = wrappers[i];

            try {
                wrapper.invokeCallouts();
                inputMessage.ExecuteDuration__c = System.Now().getTime() - startStamp.getTime();
            } catch (Exception e) {
                inputMessage.Exception__c = e.getMessage().abbreviate(SObjectType.Message__c.Fields.Exception__c.Length);
                inputMessage.Cause__c = new ExceptionSerializer(e).getAsString().abbreviate(SObjectType.Message__c.Fields.Cause__c.Length);
                inputMessage.ExecuteDuration__c = System.Now().getTime() - startStamp.getTime();
            }
        }
        
        for (Integer i = 0; i < inputMessages.size(); i++) {
            Message__c inputMessage = inputMessages[i];
            DateTime startStamp = idToStartStamp.get(inputMessage.Id);
            Integer calloutDuration = (Integer)((inputMessage.ExecuteDuration__c == null) ? 0 : inputMessage.ExecuteDuration__c);

            //TODO COUNT ANY CALLOUTS
            Broker.Wrapper wrapper = wrappers[i];

            //for incrementally rolling back each message attempted
            Savepoint minor = Database.setSavepoint();
            try {
                wrapper.invokeMain();
                inputMessage.Status__c = 'Completed'; //#798
                inputMessage.Exception__c = null;
                inputMessage.Cause__c = null;
                List<Map<String,Object>> outputEvents = wrapper.Outputs;

                //wrap up results into Messages (new guys should have Position = 0)
                for (Map<String,Object> outputEvent : outputEvents) {
                    outputMessages.add(new Message__c(
                        Event__c = Json.serializePretty(outputEvent),
                        Status__c = 'Buffered'
                    ));
                }

                inputMessage.ExecuteDuration__c = calloutDuration + (System.Now().getTime() - startStamp.getTime());

            } catch (Exception e) {
                Database.rollback(minor);
                //#581 smoking gun should point at the user, NOT at our broker
                inputMessage.Exception__c = e.getMessage().abbreviate(SObjectType.Message__c.Fields.Exception__c.Length);
                inputMessage.Cause__c = new ExceptionSerializer(e).getAsString().abbreviate(SObjectType.Message__c.Fields.Cause__c.Length);
                inputMessage.ExecuteDuration__c = calloutDuration + (System.Now().getTime() - startStamp.getTime());
            }
        }
        
        //OUR FUCKUPS (after invocation)
        
        //position + 1
        new MessageSetModel(outputMessages).incrementPositions();
    }

    /**
     * #782
     *
     * Maybe we can entertain this :( because this method is now PUBLIC and not GLOBAL.
     *
     * We used to have two arguments for inputMessages and outputMessages. The idea being:
     * that inputMessages were all gonna be written away as "Completed"
     * and outputMessages were all gonna be written away as "Buffered"
     * (ka-chunk)
     *
     * But the checkmarx scanner chokes "Bulkify_Apex_Methods_Using_Collections_In_Methods"
     * which Salesforce have confirmed to be a bug... however it requires a human to do that.
     *
     * To keep the amount of back and forth and delay to a minimum, we can get away with merging
     * the two collections into one, and doing all the status changes in memory:
     * the inputMessages get "Completed" by mark()
     * and outputMessages get "Buffered" by execute()
     *
     *
     */
    public List<Database.UpsertResult> persist(List<Message__c> inputAndOutputMessages) {
        try {
            for (Message__c message : inputAndOutputMessages) {
                //we COULD have designated all output messages as Buffered
                //but it varies if the Broker is paused (they'd be Queued)
            }
            
            //transact both inputs and outputs in one fell swoop
            MessageSetModel.Inhibit = false;
            List<Database.UpsertResult> results = Database.upsert(inputAndOutputMessages, true); //all or none
            MessageSetModel.Inhibit = true;
            
            return results;
        } catch (Exception e) {
            Set<Id> messageIds = new Set<Id>();
            for (Message__c message : inputAndOutputMessages) if (message.Id != null) {
                message.Status__c = 'Started'; //#782 in-memory
                messageIds.add(message.Id);
            }
            //#836 https://github.com/bigassforce/esb/issues/836#issuecomment-83969845
            throw new EngineException(null, messageIds, e, 'Persist failure: ' + e.getMessage());
        }
    }

    
    /**
     * Formerly restartIfWorkPending
     */
    static public void run() {
        if (BrokerSetting__c.getInstance().Inhibit__c == true) System.assert(false, 'Inhibit'); //INHIBIT
        
        if (!Test.isRunningTest()) {
            Id runningUserId = OAuthSetting__c.getOrgDefaults().RunningUserId__c;
            Id userId = UserInfo.getUserId();
            if (runningUserId == null) throw new EngineException('The configured running user Id=[' + runningUserId + '] is null or invalid');
            if (runningUserId != userId) throw new EngineException('The running user context is not the same as the configured running user context');
        }
        
        Broker impl = impl();
        
        if (impl.isRunning()) {
            //don't run if already running
            return;
        }
        
        Integer worksPending = [
            SELECT COUNT()
            FROM Message__c
            WHERE Status__c = 'Buffered'
        ];
        
        if (worksPending == 0) {
            //don't run if nothing to do
            return;
        }
        
        //there are messages to process
        impl.runImpl();
    }
    
    abstract public Boolean isRunning();
     
    abstract public void runImpl();

            
    @testVisible
    static private Boolean isAllowedSessionId(String reflectorName, Id orgId) {
        Set<String> sessionIdOrgs = new Set<String>{
            '00Dj0000000I44v', // dev org - matt
            '00Dj0000001oeWV', // dev org - neil
            '00Dj0000001q22l', // dev org - harsha
            '00Do0000000dQSB', // dev org - natani
            '00Dj0000001uJgw'  // dev org - tom
        };
        Set<String> sessionIdNamespaces = new Set<String>{
            'esb',
            'esb_batchpdf',
            'esb_tooling',
            'esb_metadata'
        };
        String namespacePrefix  = reflectorName.subStringBefore('.');
        String orgId15 = String.valueOf(orgId).left(15);
 
        return sessionIdOrgs.contains(orgId15) || sessionIdNamespaces.contains(namespacePrefix);
    }
}