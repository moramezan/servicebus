public class MessageSetModel extends ApexDomain.StandardSetModel {
    
    public class ModelException extends Exception {}
    
    List<Message__c> Messages;
    
    /**
     * Prevent message inserts per #677
     * (Change this flag sparingly only)
     */
    static public Boolean Inhibit = !Test.isRunningTest();
    
    public MessageSetModel(List<Message__c> messages) {
        super(messages);
        this.Messages = messages;
    }
    
    /**
     * Killed messages are really just started exceptions that have been "moved on" to Completed.
     * We allow users to "kill" them so they don't appear as big ugly red bars in the monitor.
     *
     * @return set of actual killed message ids
     */
    public void kill() {
        Set<Id> attemptedIds = this.keySet();
        
        if (attemptedIds.isEmpty()) {
            throw new ModelException('You must select some messages.');
        }
        
        //we query on both status and exception to ensure guys
        //held up in database.stateful can't be killed. if
        //someone aborts the batch job, yep they stuck forever
        List<Message__c> killableMessages = [
            SELECT Id, Status__c
            FROM Message__c
            WHERE Id IN :attemptedIds
            AND (Status__c = 'Paused' OR Exception__c != null)
            FOR UPDATE
        ];
        
        if (killableMessages.isEmpty()) {
            //maybe selected messages were not killable...
            throw new ModelException('Only Paused or Exception messages can be killed.');
        }
        
        for (Message__c killableMessage : killableMessages) {
            
            if (killableMessage.Status__c == 'Paused') {
                //#1191 paused messages are killable
                killableMessage.Exception__c = 'Killed by ' + UserInfo.getName();
            }
            
            //per #825 and #827 we do NOT clear cause/exception
            killableMessage.Status__c = 'Completed';
        }
        
        update killableMessages;
    }
    
    /**
     * "Rebuffering" is the asynchronous re-attempt of
     * several messages, with the hope of them re doing
     * successfully (presumably after changing the service)
     */
    public void rebuffer() {
        Set<Id> attemptedIds = this.keySet();
        
        if (attemptedIds.isEmpty()) {
            throw new ModelException('You must select some messages.');
        }
        
        List<Message__c> rebufferableMessages = [
            SELECT Id
            FROM Message__c
            WHERE Id IN :attemptedIds
            AND (Status__c = 'Paused' OR Exception__c != null)
        ];
        
        if (rebufferableMessages.isEmpty()) {
            //maybe selected messages were not killable...
            throw new ModelException('Only Paused or Exception messages can be rebuffered.');
        }
        
        for (Message__c rebufferableMessage : rebufferableMessages) {
            rebufferableMessage.Status__c = 'Buffered';
            rebufferableMessage.Exception__c = null; //#827
            rebufferableMessage.Cause__c = null; //#827
        }
        
        update rebufferableMessages;
        
        //#952 restart REAL broker asynchronously
        System.Queueable job = new Job();
        if (!Application__c.getOrgDefaults().BrokerIsPaused__c) System.enqueueJob(job); //#1215 only start if not paused
    }
    
    /**
     * Determines which messages are eligible to be moved into the Started status (by finding Messages
     * with 'Buffered' status).
     *
     * Messages that should be worked on have their status marked as Started in the database before being
     * submitted the query locator. That way, if any given execution fails, those messages will remain in the
     * easily identifiable 'Started' state.
     *
     * CONTEXT A:
     * - Persist (from previous)
     * - Locate (lock for update)
     * - Mark (performs update and puts into stateful, safe from clutches of other jobs)
     *
     * CONTEXT B:
     * - Execute (reads guys off stateful property, does work and performs update)
     *
     * @return collection of soon-to-be-marked-as-Started Messages.
     */
    static public MessageSetModel locateMarkableWork() {
        
        List<Message__c> specimen = [
            SELECT Id, Route__c, Event__c
            FROM Message__c
            WHERE Status__c = 'Buffered'
            ORDER BY CreatedDate ASC //reattempts will naturally lead
            LIMIT 1
        ];
        
        if (specimen.isEmpty()) {
            //no work found, return empty
            return new MessageSetModel(new List<Message__c>());
        }
        
        Integer chunks = 1;
        
        try {
            //resolve class name
            String apexTypeName = specimen[0].Route__c;
            Step__c step = Step__c.getValues(specimen[0].Route__c);
            if (step != null) apexTypeName = step.ApexTypeName__c;
            
            //peek at summary
            ApexClassModel.Summary summary; //unit tests skip cache
            if (Test.isRunningTest()) summary = new ApexClassModel.Summary(Type.forName(apexTypeName));
            else if (!Test.isRunningTest()) summary = ApexClassSetModel.loadCache().get(apexTypeName);
            chunks = summary.Chunks;
            
        } catch (Exception e) {}
        
        return new MessageSetModel([
            SELECT Id, Route__c, Event__c
            FROM Message__c
            WHERE Status__c = 'Buffered'
            AND Route__c = :specimen[0].Route__c //#1004 Route__c field only ever used here to LOCATE, and for GATE and MONITOR
            LIMIT :chunks
            FOR UPDATE //#695 investigate broker race condition
        ]);
    }
    
    /**
     * Sets many Messages statuses to 'Started' and writes them away.
     * TODO we should be REALLY careful here because it modifies BY REFERENCE
     */
    public List<Message__c> mark(String slot) {
        
        for (Message__c message : this.Messages) {
            //message fields
            message.Slot__c = slot; //store
            message.Status__c = 'Started';
            
            try {
                //resolve class name
                String apexTypeName = message.Route__c;
                Step__c step = Step__c.getValues(message.Route__c);
                if (step != null) apexTypeName = step.ApexTypeName__c;
                
                //peek at summary
                ApexClassModel.Summary summary; //unit tests skip cache
                if (Test.isRunningTest()) summary = new ApexClassModel.Summary(Type.forName(apexTypeName));
                else if (!Test.isRunningTest()) summary = ApexClassSetModel.loadCache().get(apexTypeName);
                message.IsAutoRetryable__c = summary.Retry;
                
            } catch (Exception e) {}
            
            //increment attempts
            if (message.NumberOfAttempts__c == null) message.NumberOfAttempts__c = 0;
            message.NumberOfAttempts__c++;
        }
        
        update this.Messages;
        return this.Messages;
    }
    
    /**
     * Resolves and invokes the toStringable Object for one input, updating an in-memory collection of outputs
     *
     * @param  inputMessages pass-by-reference Messages whose status should be Started
     * @param  outputMessages pass-by-reference Messages whose status should be Started
     */
    public List<Message__c> execute(Broker.BatchImpl impl) {
        
        //empty inputs, empty outputs
        if (this.Messages.isEmpty()) return new List<Message__c>();
        
        //TODO throw new ServiceException('Execute panic:' + e.getMessage() + ' - ' + e.getStackTraceString(), e);
        List<Message__c> inputMessages = this.Messages;
        List<Message__c> outputMessages = new List<Message__c>();
        
        for (Integer i = 0; i < inputMessages.size(); i++) {
            //event params
            MessageModel model = new MessageModel(inputMessages[i]);
            model.setParam('Range', inputMessages.size());
            model.setParam('Chunk', i + 1); //chunks are 1-indexed
            model.setParam('SiblingIds', this.keySet());
        }
        
        //OUR FUCKUPS (prepare)
        List<MessageModel> models = new List<MessageModel>();
        for (Message__c message : this.Messages) {
            MessageModel model = new MessageModel(message);
            models.add(model);
        }
        
        //THEIR FUCKUPS (callout)
        for (MessageModel model : models) {
            //do invocation
            if (impl != null) impl.FatalMessageId = model.getId(); //#985
            if (impl != null) impl.FatalCpuTime = Datetime.now().getTime(); //#985
            model.invokeCallout();
        }
        
        //for isolating chunks from each other
        Savepoint sp = Database.setSavepoint();
        Boolean isolate = false;
        
        //THEIR FUCKUPS (execute)
        for (MessageModel model : models) {
            
            if (isolate) {
                //consume savepoint only if necessary (side effects)
                sp = Database.setSavepoint();
                isolate = false;
            }
            
            //do invocation
            if (impl != null) impl.FatalMessageId = model.getId(); //#985
            if (impl != null) impl.FatalCpuTime = Datetime.now().getTime(); //#985
            isolate = model.invokeExecute(outputMessages);
            
            if (model.Message.Exception__c != null && isolate) {
                //consume rollback only if necessary (error AND side effects)
                Database.rollback(sp);
            }
        }
        
        return outputMessages;
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
    public void persist(List<Message__c> outputMessages) {
        
        /**
         * The input messages get 'slot' put on them in the mark. We clear it out
         * here in the persist. Leftover 'slot' is a good indicator of fatalities.
         */
        for (Message__c inputMessage : this.Messages) {
            inputMessage.Slot__c = null; //clear
        }
        
        /**
         * Since we want any "resolve" to happen in ONE place, this appears to
         * be the only place left to put it. Here in the persist works OK because
         * output messages are NEW ONES. Existing ones won't get re incremented.
         * Notice how our Enqueue method persists the outputs, not the inputs!
         */
        for (Message__c outputMessage : outputMessages) try {
            MessageModel model = new MessageModel(outputMessage);
            
            //#1147 routing
            try {
                Map<String,Object> outputEvent = model.getEvent();
                ApexClassModel.route(outputEvent);
                model.setEvent(outputEvent);
            } catch (Exception e) {
                if (Test.isRunningTest()) throw e;
            }
            
            //resolve config id (OF INCREMENTED ROUTE!) //TODO test this
            Id configId = null;
            Step__c step = Step__c.getValues((String)model.getParam('Route'));
            if (step != null) configId = step.ConfigId__c;
            
            //#856 this will add the step config id
            model.setParam('StepConfigId', configId);
            
        } catch (Exception e) {
            if (Application__c.getOrgDefaults().Prefix__c == null) throw e;
        }
        
        //transact combined inputs and outputs in one fell swoop
        List<Message__c> messages = new List<Message__c>();
        messages.addAll(this.Messages);
        messages.addAll(outputMessages);
        MessageSetModel.Inhibit = false;
        ApexDomain.crudFls(SObjectType.Message__c.Createable);
        Database.upsert(messages);
        MessageSetModel.Inhibit = true;
        
        //#1114 poor mans message cleanup strategy
        List<Id> completedMessageIds = new List<Id>();
        for (Message__c inputMessage : this.Messages) if (inputMessage.Status__c == 'Completed') completedMessageIds.add(inputMessage.Id);
        Database.delete(completedMessageIds, false); //#1136 partial delete allowed
    }
    
    /**
     * Fields can only be changed if Apex is
     * used to unset the Inhibit static.
     */
    @TestVisible void inhibitCreationFromGui() {
        for (Message__c message : this.Messages) {
            if (Inhibit) message.addError('Messages cannot be created from the GUI.');
        }
    }
    
    override public void onBeforeInsert() {
        this.inhibitCreationFromGui();
        this.alphabetizeJsonAndPopulateFields();
        this.swallowToString();
    }
    
    override public void onAfterInsert() {
        //#1038 update immediately to populate message ids, avoid memory leak in mark
        List<Message__c> messages = new List<Message__c>();
        for (Message__c message : this.Messages) messages.add(new Message__c(Id = message.Id));
        update messages; //touch
    }
    
    override public void onAfterUndelete() {
        for (Message__c message : this.Messages) {
            //#1185 inhibit undelete
            message.addError('Messages cannot be undeleted. Inhibit the delete instead.');
        }
    }
    
    override public void onBeforeUpdate(List<SObject> oldObjects) {
        this.alphabetizeJsonAndPopulateFields();
        this.swallowToString();
    }
    
    /**
     * Ensure that Event parameters are always valid JSON #660
     * So that we can trust them in the Broker and keep code simple.
     */
    @TestVisible void alphabetizeJsonAndPopulateFields() {
        for (Message__c message : this.Messages) try {
            if (message.Event__c == null) System.assert(false, 'Event was null!'); //TODO message.Event__c = '{}';
            
            //#1125 not using message model here... because want to completely blat keys!
            Map<String,Object> event = (Map<String,Object>)Json.deserializeUntyped(message.Event__c);
            
            //strip out our little secrets
            event.remove('AllowsCallouts');
            event.remove('Chunk');
            event.remove('Range');
            event.remove('SiblingIds'); //#1026
            
            //#1026 this guy wont be visible unless requeried after update
            if (message.Id != null) event.put('MessageId', message.Id);
            
            //#1004 Route__c field only ever used to LOCATE, and for GATE and MONITOR (we can clear it as well as setting in)
            if (event.containsKey('Route')) message.Route__c = (String)event.get('Route'); else message.Route__c = null;
            
            /**
             * Populates the Unique Correlation Uuid
             * This parameter surfaced onto the message to support the
             * functionality in the Aggregate By Correlation Uuid service
             */
            String correlationUuid = (String)event.get('CorrelationUuid'); //this field only ever used to AGGREGATE BY CORRELATION UUID
            if (correlationUuid != null) message.CorrelationUuid__c = correlationUuid;
            
            /**
             * Populates the Queueable Id
             * This parameter surfaced onto the message to support the
             * functionality in the Aggregate By Job service
             */
            Id jobId = (Id)event.get('JobId'); //this field only ever used to AGGREGATE BY JOB
            if (jobId != null) message.JobId__c = jobId;
            
            //#972 reserialize in alphabetical order
            message.Event__c = new SortedSerializer(event).toString();
        } catch (JsonException e) {
            message.Event__c.addError(e);
        }
    }
    
    /**
     * Swallow toString() in trace
     * The intent is to NOT confuse or misdirect the end user and to .. (cough) .. reveal our secret sauce
     * https://github.com/bigassforce/servicebus/issues/581
     * https://github.com/bigassforce/servicebus/commit/2dd94e19c156170b86dc30b50e5e375876f5e758
     */
    @TestVisible void swallowToString() {
        for (Message__c message : this.Messages) {
            if (message.Cause__c != null) {
                message.Cause__c = message.Cause__c.replace('\n(esb)', '');
                message.Cause__c = message.Cause__c.replace('\n(abstract)', '');
                message.Cause__c = message.Cause__c.replace('\n(servicebus)', '');
                message.Cause__c = message.Cause__c.replace('\nExternal entry point', '');
                message.Cause__c = message.Cause__c.replace('\nAnonymousBlock: line 1, column 1', '');
            }
        }
    }
    
    static public void pauseQueue() {
        //fetch custom setting and set the flag
        Application__c application = Application__c.getOrgDefaults();
        application.BrokerIsPaused__c = true;
        upsert application;
    }
    
    static public void resumeQueue() {
        //fetch custom setting and unset the flag
        Application__c application = Application__c.getOrgDefaults();
        application.BrokerIsPaused__c = false;
        upsert application;
        
        //get all the paused guys
        List<Message__c> messages = [
            SELECT Id
            FROM Message__c
            WHERE Status__c = 'Paused'
            LIMIT :Limits.getLimitDmlRows() //if more than 10,000 you could click Resume multiple times
        ];
        
        //Why do we have an extra status Paused?
        //So that they can be excluded from the RESOLVE / MARK cycle at a very early stage.
        //We want to be able to reintroduce messages on a one-by-one basis without turning on the tap.
        
        //advance them from Paused to Buffered
        for (Message__c message : messages) message.Status__c = 'Buffered';
        update messages;
        
        //#952 restart REAL broker
        System.Queueable job = new Job();
        System.enqueueJob(job);
    }
    
    /**
     * #972
     * Usage:
     * new SortedSerializer(myEx).toString();
     */
    public class SortedSerializer {
        
        //true for pretty printing
        JsonGenerator g = Json.createGenerator(true);
        
        public SortedSerializer(Object obj) {
            if (obj == null) {
                this.g.writeNull();
            } else if (obj instanceof Map<String,Object>) {
                this.traverseMap((Map<String,Object>)obj);
            } else if (obj instanceof List<Object>) {
                this.traverseList((List<Object>)obj);
            } else { //obj instanceof Object
                this.g.writeObject(obj);
            }
        }
        
        override public String toString() {
            return g.getAsString();
        }
        
        void traverseMap(Map<String,Object> obj) {
            List<String> keys = new List<String>(obj.keySet());
            keys.sort();
            
            this.g.writeStartObject();
            for (String key : keys) {
                Object value = obj.get(key);
                this.g.writeFieldName(key);
                
                if (value == null) {
                    this.g.writeNull();
                } else if (value instanceof Map<String,Object>) {
                    this.traverseMap((Map<String,Object>)value);
                } else if (value instanceof List<Object>) {
                    this.traverseList((List<Object>)value);
                } else { //value instanceof Object
                    this.g.writeObject(value);
                }
            }
            this.g.writeEndObject();
        }
        
        void traverseList(List<Object> objs) {
            this.g.writeStartArray();
            for (Object obj : objs) {
                if (obj == null) {
                    this.g.writeNull();
                } else if (obj instanceof Map<String,Object>) {
                    this.traverseMap((Map<String,Object>)obj);
                } else if (obj instanceof List<Object>) {
                    this.traverseList((List<Object>)obj);
                } else { //obj instanceof Object
                    this.g.writeObject(obj);
                }
            }
            this.g.writeEndArray();
        }
        
    }
    
}