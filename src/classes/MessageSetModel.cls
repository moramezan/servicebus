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
     * several messages, with the hope of them reprocessing
     * successfully (presumably after changing the process)
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
    
    override public void onAfterInsert() {
        this.inhibitCreationFromGui();
    }
    
    override public void onBeforeInsert() {
        this.validateJsonParameters();
        this.populateJsonFields();
        this.swallowToString();
    }
    
    override public void onBeforeUpdate(List<SObject> oldObjects) {
        this.validateJsonParameters();
        this.populateJsonFields();
        this.swallowToString();
    }
    
    @TestVisible private void populateJsonFields() {
        for (Message__c message : this.Messages) {
            Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(message.Event__c);
            
            /**
             * It's not sensible to query on the JSON formatted SequenceName and Position
             * but what we can do is make sure those guys are always concatenated into a key.
             * TODO #956 try to route everyone except heartbeats per #575
             */
            String sequence = (String)parameters.get('__SequenceName');
            Integer position = (Integer)parameters.get('__Position');
            if (sequence != null && position != null) message.Step__c = sequence + '#' + position;
            
            /**
             * Populates the Unique Entry Point Id
             * This parameter surfaced onto the message to support the
             * functionality in the Gate By Entry Point process
             */
            message.EntryPointUuid__c = (String)parameters.get('esb__EntryPointUuid');
            
            /**
             * Populates the Queueable Id
             * This parameter surfaced onto the message to support the
             * functionality in the Gate By Job process
             */
            message.QueueableId__c = (String)parameters.get('__QueueableId');
        }
    }
    
    /**
     * Ensure that Message Parameters are always valid JSON #660
     * So that we can trust them in the Broker and keep code simple.
     */
    @TestVisible private void validateJsonParameters() {
        for (Message__c message : this.Messages) {
            try {
                Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(message.Event__c);
            } catch (JsonException e) {
                message.Event__c.addError(e);
            }
        }
    }
    
    /**
     * Swallow toString() in trace
     * The intent is to NOT confuse or misdirect the end user ant to .. (cough) .. reveal our secret sauce
     */
    @TestVisible private void swallowToString() {
        for (Message__c message : this.Messages) {
            if (message.Cause__c != null) {
                message.Cause__c = message.Cause__c.replaceAll('Class.BaseProcess.toString[^\n]+\n', '');
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
    
}