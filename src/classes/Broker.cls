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
    
    public static Integer MaxHops = 500;
    
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
        
        Integer count = [
            SELECT COUNT()
            FROM Message__c
            WHERE Status__c = 'Buffered'
        ];
        
        if (count == 0) {
            //no work found, return empty
            return new List<Message__c>();
        }
        
        Message__c specimen = [
            SELECT Id, Step__c, Event__c, Status__c, Attempts__c
            FROM Message__c
            WHERE Status__c = 'Buffered'
            ORDER BY CreatedDate ASC //reattempts will naturally lead
            LIMIT 1
        ];
        
        ApexClassModel.ESB model = new MessageModel(specimen).discoverProcessModel();
        
        if (model == null) {
            //cannot discover process, return one specimen
            return new List<Message__c>{specimen};
        }
        
        Integer limits = model.Limits; //number of times specimen process can run within governor limits
        
        List<Message__c> messages = [
            SELECT Id, Step__c, Event__c, Status__c, Attempts__c
            FROM Message__c
            WHERE Status__c = :specimen.Status__c
            AND Step__c = :specimen.step__c
            LIMIT :limits
            FOR UPDATE //#695 investigate broker race condition
        ];
        
        Step__c step = new MessageModel(specimen).resolveStep();
        
        if (step == null) {
            //cannot resolve step, return unconfigured
            return messages;
        }
        
        Id configId = step.ConfigId__c;
        
        if (configId == null) {
            //config id is null, strip and return unconfigured
            new MessageSetModel(messages).putStepConfig(null);
            return messages;
        }
        
        SObject stepConfig = ApexDomain.getById(configId);
        
        if (stepConfig == null) {
            //step config is null, strip and return unconfigured
            new MessageSetModel(messages).putStepConfig(null);
            return messages;
        }
        
        //put hydrated config on each message and return
        new MessageSetModel(messages).putStepConfig(stepConfig);
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
            throw new EngineException('Mark exception: ' + e.getMessage(), e);
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
        List<MessageModel> models = new List<MessageModel>();
        for (Message__c inputMessage : inputMessages) {
            try {
                //check sequence, position, step, reflector, etc
                models.add(new MessageModel(inputMessage));
                
            } catch (MessageModel.MessageException e) {
                //bigger problems (inputMessage shows by reference)
                return;
                
            }
        }
        
        //specimen #575 crow look, go directly to heartbeat process, do not pass go, do not collect $200
        if (models[0].Event.get('__IsHeartbeatProcess') != null) {
            
            for (MessageModel model : models) {
                
                //#697 locateMarkableWork misses this for heartbeats
                model.setFullyQualifiedClassName(Heartbeat.class);
                
                try {
                    //do invocation
                    model.invokeExecute(outputMessages);
                    
                } catch (MessageModel.MessageException e) {
                    //bigger problems
                    continue;
                    
                }
            }
            
            //end special routing
            return;
        }
        
        //THEIR FUCKUPS (invocation)
        for (MessageModel model : models) {
            try {
                //do invocation
                model.invokeCallouts();
                
            } catch (MessageModel.MessageException e) {
                //postpone any handling after finally block
                continue;
                
            }
        }
        
        //for incrementally rolling back each message attempted
        Savepoint sp = Database.setSavepoint();
        
        //savepoint tax only applies if side effects
        Boolean hadSideEffects = false;
        
        for (MessageModel model : models) {
            //consume savepoint only if necessary
            if (hadSideEffects) {
                sp = Database.setSavepoint();
                hadSideEffects = false;
            }
            
            //measure side effects before
            Integer queueables = Limits.getQueueableJobs();
            Integer futures = Limits.getFutureCalls();
            Integer emails = Limits.getEmailInvocations();
            Integer dmls = Limits.getDMLStatements();
            
            Boolean hadException = false;
            
            try {
                //do invocation
                model.invokeExecute(outputMessages);
                
            } catch (MessageModel.MessageException e) {
                //postpone any handling after finally block
                hadException = true;
                
            } finally {
                //measure side effects after, whether or not there was an exception
                if (Limits.getEmailInvocations() > emails) hadSideEffects = true;
                if (Limits.getQueueableJobs() > queueables) hadSideEffects = true;
                if (Limits.getDMLStatements() > dmls) hadSideEffects = true;
                if (Limits.getFutureCalls() > futures) hadSideEffects = true;
            }
            
            //consume rollback only if necessary
            if (hadSideEffects && hadException) Database.rollback(sp);
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

    static public Boolean isAllowedSessionId(String reflectorName, Id orgId) {
        if (!Test.isRunningTest() && Broker.class.getName() == 'Broker') return true; //unmanaged deployment ok
        
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