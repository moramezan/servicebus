public with sharing class MessageSetModel extends ApexDomain.StandardSetModel {
    
    /**
     * Prevent message inserts per #677
     * (Change this flag sparingly only)
     */
    static public Boolean Inhibit = !Test.isRunningTest();
    
    /**
     * #829 try to prevent "too many query rows" by cleaning
     * or housekeeping only once per execution context
     */
    @TestVisible static private Boolean IsCleaned = false;
    @TestVisible static private Integer MaxTotalMessages     = 5000; 
    
    public MessageSetModel(List<Message__c> messages) {
        super(messages);
    }
    
    /**
     * Fields can only be changed if Apex is
     * used to unset the Inhibit static.
     */
    @TestVisible private void inhibitCreationFromGui() {
        List<Message__c> messages = this.getRecords();
        
        for (Integer i = 0; i < messages.size(); i++) {
            if (Inhibit) messages[i].addError('Messages cannot be created from the GUI.');
        }
    }
    
    override public void onBeforeInsert() {
        this.inhibitCreationFromGui();
        this.validateJsonParameters();
        this.interpretEsbSequenceName();
        this.incrementHops();
        this.populateRouteKey();
        this.swallowToString();
        this.populateQueueableId();
    }
    
    override public void onBeforeUpdate(List<SObject> oldObjects) {
        this.validateJsonParameters();
        this.interpretEsbSequenceName();
        this.populateRouteKey();
        this.swallowToString();
    }
    
    /**
     * Unrelated to former term "resolve" (which now refers to PROCESS location)
     * this is just a convenience to increment the position of a bunch of messages.
     */
    public void incrementPositions() {
        List<Message__c> messages = this.getRecords();
        for (Message__c message : messages) {
            Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(message.Event__c);
            Integer position = (Integer)parameters.get('__Position');
            parameters.put('__Position', ++position);
            message.Event__c = Json.serializePretty(parameters);
        }
    }
    
    /**
     * #694 puts QueueableContext Job Id on messages. Because when people
     * use System.enqueueJob to enqueue a message into the system, they will
     * never get a Message Id. But at least we have a possibility of using
     * the Queueable AsyncApexJob Id as a correlation later for Capture etc.
     */
    public void populateQueueableId(QueueableContext context) {
        List<Message__c> messages = this.getRecords();
        for(Message__c message : messages) {
            Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(message.Event__c);
            Id queueableId = context.getJobId();
            parameters.put('__QueueableId', queueableId);
            message.Event__c = Json.serializePretty(parameters);
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
     * We cannot simply increment __Hops BEFORE calling invoke as a process writer could fuck with this parameter
     * Instead we read and increment __Hops BEFORE calling invoke using enforceMaxHops()
     * and assign to an Integer hops variable
     * We use applyHops()  to apply the incremented hops variable to the __Hops parameter of
     * all messages returned from invoke()
     */
    public void incrementHops() {
        List<Message__c> messages = this.getRecords();
        for (Message__c message : messages) {
            Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(message.Event__c);
            Integer hops = (Integer)parameters.get('__Hops');
            if (hops == null) continue; //nothing to do
            
            parameters.put('__Hops', ++hops);
            message.Event__c = Json.serializePretty(parameters);
        }
    }
    
    /**
     * In #658 we hoped to expose esb__SequenceName API in Broker.persist() but
     * it meant we can't insert messages then just 'run' broker over them. Further
     * issue #677 feels like we probably shouldn't be inserting messages at all.
     * 
     * We want to interpret esb__SequenceName into __SequenceName and __Position
     * as late and as simply as possible. Doing it here in the trigger works OK.
     */
    public void interpretEsbSequenceName() {
        List<Message__c> messages = this.getRecords();
        for (Message__c message : messages) {
            //user nominated Sequence (no esb prefix)
            Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(message.Event__c);
            if (parameters.get('esb__SequenceName') == null) continue; //nothing to do
            
            parameters.put('__SequenceName', parameters.get('esb__SequenceName'));
            parameters.put('__Position', 1);
            parameters.put('esb__SequenceName', null);
            message.Event__c = Json.serializePretty(parameters);
        }
    }
    
    /**
     * It's not sensible to query on the JSON formatted SequenceName and Position
     * but what we can do is make sure those guys are always concatenated into a key.
     */
    @TestVisible private void populateRouteKey() {
        List<Message__c> messages = this.getRecords();
        
        for (Message__c message : messages) {
            Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(message.Event__c);
            Boolean isHeartbeatProcess = (Boolean)parameters.get('__IsHeartbeatProcess');
            if (isHeartbeatProcess == true) continue; //#575 crow look, don't try to route
            
            String sequence = (String)parameters.get('__SequenceName');
            Integer position = (Integer)parameters.get('__Position');
            message.Route__c = sequence + '#' + position;
        }
    }
    
    /**
     * Ensure that Message Parameters are always valid JSON #660
     * So that we can trust them in the Broker and keep code simple.
     */
    @TestVisible private void validateJsonParameters() {
        List<Message__c> messages = this.getRecords();
        
        for (Message__c message : messages) {
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
        List<Message__c> messages = this.getRecords();
        for (Message__c message : messages) {
            if (message.Cause__c != null) {
            	message.Cause__c = message.Cause__c.replaceAll('Class.BaseProcess.toString[^\n]+\n', '');    
            }
        }
    } 
    
    /**
     * Populates the enqueue Id
     * This parameter surfaced onto the message to support the
     * functionality in the EnqueueGate
     */
    @TestVisible private void populateQueueableId() {
        List<Message__c> messages = this.getRecords();

        for (Message__c message : messages) {
            Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(message.Event__c);
            message.QueueableId__c = (String)parameters.get('__QueueableId');
        }
    }
    
}