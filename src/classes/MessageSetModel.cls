public class MessageSetModel extends ApexDomain.StandardSetModel {
    
    public class MessageException extends Exception {}
    
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
            throw new MessageException('You must select some messages.');
        }
        
        //we query on both status and exception to ensure guys
        //held up in database.stateful can't be killed. if
        //someone aborts the batch job, yep they stuck forever
        List<Message__c> killableMessages = [
            SELECT Id
            FROM Message__c
            WHERE Id IN :attemptedIds
            AND Status__c = 'Started'
            AND Exception__c != null
            FOR UPDATE
        ];
        
        if (killableMessages.isEmpty()) {
            //maybe selected messages were not killable...
            throw new MessageException('Only messages with an Exception can be killed.');
        }
        
        for (Message__c killableMessage : killableMessages) {
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
            throw new MessageException('You must select some messages.');
        }
        
        List<Message__c> rebufferableMessages = [
            SELECT Id
            FROM Message__c
            WHERE Id IN :attemptedIds
            AND Status__c IN ('Started', 'Completed')
            AND Exception__c != null
        ];
        
        if (rebufferableMessages.isEmpty()) {
            //maybe selected messages were not killable...
            throw new MessageException('Only messages with an Exception can be rebuffered.');
        }
        
        for (Message__c rebufferableMessage : rebufferableMessages) {
            rebufferableMessage.Status__c = 'Buffered';
            rebufferableMessage.Exception__c = null; //#827
            rebufferableMessage.Cause__c = null; //#827
        }
        
        update rebufferableMessages;
        
        //#952 restart REAL broker
        System.Queueable job = new Job();
        System.enqueueJob(job);
    }
    
    /**
     * Fields can only be changed if Apex is
     * used to unset the Inhibit static.
     */
    @TestVisible private void inhibitCreationFromGui() {
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
    
    override public void onBeforeUpdate(List<SObject> oldObjects) {
        this.alphabetizeJsonAndPopulateFields();
        this.swallowToString();
    }
    
    /**
     * Ensure that Event parameters are always valid JSON #660
     * So that we can trust them in the Broker and keep code simple.
     */
    @TestVisible private void alphabetizeJsonAndPopulateFields() {
        for (Message__c message : this.Messages) try {
            if (message.Event__c == null) message.Event__c = '{}';
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
             * Populates the Unique Entry Point Id
             * This parameter surfaced onto the message to support the
             * functionality in the Aggregate By Entry Point service
             */
            String entryPointUuid = (String)event.get('EntryPointUuid'); //this field only ever used to AGGREGATE BY ENTRY POINT
            if (entryPointUuid != null) message.EntryPointUuid__c = entryPointUuid;
            
            /**
             * Populates the Queueable Id
             * This parameter surfaced onto the message to support the
             * functionality in the Aggregate By Job service
             */
            Id jobId = (Id)event.get('JobId'); //this field only ever used to AGGREGATE BY JOB
            if (jobId != null) message.JobId__c = jobId;
            
            //#972 reserialize in alphabetical order
            message.Event__c = new SortedSerializer(event).toString();
        } catch (Exception e) {
            message.Event__c.addError(e);
        }
    }
    
    /**
     * Swallow toString() in trace
     * The intent is to NOT confuse or misdirect the end user and to .. (cough) .. reveal our secret sauce
     * https://github.com/bigassforce/servicebus/issues/581
     * https://github.com/bigassforce/servicebus/commit/2dd94e19c156170b86dc30b50e5e375876f5e758
     */
    @TestVisible private void swallowToString() {
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
        BrokerSetting__c setting = BrokerSetting__c.getOrgDefaults();
        setting.IsPaused__c = true;
        upsert setting;
    }
    
    static public void resumeQueue() {
        //fetch custom setting and unset the flag
        BrokerSetting__c setting = BrokerSetting__c.getOrgDefaults();
        setting.IsPaused__c = false;
        upsert setting;
        
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