/**
 * Domain layer for Message__c model
 */
public class MessageModel extends ApexDomain.StandardModel {
    
    /**
     * User process instance (transient prevents inadvertent toString() / serialization)
     */
    transient private Object Process;
    
    /**
     * Event parameters
     */
    public Map<String,Object> Event;
    
    /**
     * Signal exception, by prepare / callouts / execute
     */
    public Boolean IsFucked = false;
    
    /**
     * Signal this process causes any change to any state
     */
    public Boolean HadSideEffects = false;
  
    /**
     * Used in prepare and later in execute
     */
    @TestVisible private Type reflector;
    
    /**
     * These are all examples of "bigger problems"
     */
    public MessageModel(Message__c message) {
        super(message);
        this.Message = message;
        this.Event = (Map<String,Object>)Json.deserializeUntyped(message.Event__c);
    }
    
    static public MessageModel fromId(Id messageId) {
        Message__c message = (Message__c)ApexDomain.getById(messageId);
        return new MessageModel(message);
    }
    
    /**
     * For advertising domain layer errors
     */
    public class MessageException extends Exception {}
    
    /**
     * For cast-free convenience
     */
    private Message__c Message;
    
    /**
     * Prepare the exception message and the exception cause
     */
    public void prepareException(Exception e) {
        this.Message.Exception__c = e.getMessage().abbreviate(SObjectType.Message__c.Fields.Exception__c.Length);
        this.Message.Cause__c = new ExceptionSerializer(e).getAsString().abbreviate(SObjectType.Message__c.Fields.Cause__c.Length);
    }
    
    /**
     * Returns STEP or NULL
     */
    public Step__c resolveStep() {
        
        String route = this.message.Step__c;
        if (route == null) return null; //message has no route
        
        return Step__c.getValues(route);
    }
    
    /**
     * This performs actual resolution inside the broker execute method.
     */
    public void prepareProcess() {
        this.Message.ExecuteDuration__c = 0;
        Long timer = System.now().getTime();
        
        try {
            Integer hops = (Integer)this.Event.get('__Hops');
            
            if (hops >= Broker.MaxHops) {
                throw new MessageException('Too many hops - to resolve, manually set __Hops on event parameters to 0');
            }
            
            String route = this.message.Step__c;
            
            if (route == null) {
                throw new MessageException('This message has no route: ' + this.message.Id);
            }
            
            Step__c step = Step__c.getValues(route);
            
            if (step == null) {
                throw new MessageException('Nonexistent route, eg bad sequence name, position, missing terminate: ' + route);
            }
            
            String apexClassName = step.ApexClassName__c;
            
            if (apexClassName == null) {
                throw new MessageException('Step fully qualified class name was null: ' + step.Id);
            }
            
            this.reflector = Type.forName(apexClassName);
            
            if (this.reflector == null) {
                throw new MessageException('Reflector for classname was null: ' + apexClassName);
            }
            
            this.Process = this.reflector.newInstance();
            
        } catch (Exception e) {
            this.prepareException(e);
            this.IsFucked = true;
            
        }
        
        //execution time profiler
        if (this.Message.ExecuteDuration__c == null) this.Message.ExecuteDuration__c = 0;
        this.Message.ExecuteDuration__c += System.now().getTime() - timer;
    }
    
    /**
     * TODO COUNT ANY DMLS
     */
    public void invokeCallouts() {
        Long timer = System.now().getTime();
        
        //skip bad guys
        if (this.IsFucked) return;
        
        try {
            //provide input event and set flag
            Job.Event = this.Event.clone();
            Job.Event.put('esb__AllowsCallouts', true);
            
            //do callouts
            
            String data = String.valueOf(process);
            if (data != null) throw new MessageException('Your AllowsCallouts code block should return null.');
            
        } catch (Exception e) {
            //smoking gun should point at user
            this.prepareException(e);
            this.IsFucked = true;
            
        }
        
        //execution time profiler
        if (this.Message.ExecuteDuration__c == null) this.Message.ExecuteDuration__c = 0;
        this.Message.ExecuteDuration__c += System.now().getTime() - timer;
    }
    
    /**
     * TODO COUNT ANY CALLOUTS
     */
    public void invokeExecute(List<Message__c> outputMessages) {
        Long timer = System.now().getTime();
        
        //skip bad guys
        if (this.IsFucked) return;
        
        //measure side effects before
        Integer futureCalls = Limits.getFutureCalls();
        Integer queueableJobs = Limits.getQueueableJobs();
        Integer dmlStatements = Limits.getDMLStatements();
        Integer emailInvocations = Limits.getEmailInvocations();
        
        try {
            if (outputMessages == null) {
                //our own fault
                throw new MessageException('MessageModel.invokeExecute must receive REFERENCE to list of output messages.');
            }
            
            //provide input event and set flag
            Job.Event = this.Event.clone();
            Job.Event.put('esb__AllowsCallouts', false);
            
            //#877 surface SessionId to select few orgs and packages
            //Boolean allowSessionId = Broker.isAllowedSessionId(step.ApexClassName__c, UserInfo.getOrganizationId());
            //if (allowSessionId) Job.Event.put('__SessionId', OAuthSetting__c.getOrgDefaults().AccessToken__c);
            //TODO for #886
            
            //do invocation
            String data = String.valueOf(process);
            if (data == 'null') {
                //#945 watch out for the STRING NULL that comes out
                throw new MessageException('Your main code block should return a List<Map<String,Object>>.');
            }
            
            //#886 normalise class name (we will test for absence of this fragment at start of process toString)
            String fragment = this.Reflector.getName();
            if (fragment.contains('.')) fragment = fragment.substringAfter('.');
            fragment += ':[';
            
            //#886
            if (data.startsWith(fragment)) throw new MessageException('Your plugin has not extended abstract process. Please refer to the Process Developers Guide for specific guidance.');


            //wrap up results into Messages (new guys should have Position = 0)
            List<Object> outputEvents = (List<Object>)Json.deserializeUntyped(data);
            
            for (Object outputEvent : outputEvents) {
                outputMessages.add(new Message__c(
                    Event__c = Json.serializePretty(outputEvent),
                    Status__c = 'Buffered'
                ));
            }
            
            this.Message.Cause__c = null;
            this.Message.Exception__c = null;
            this.Message.Status__c = 'Completed'; //#798
            //clear any errors off the input message as the LAST thing
            //wait... if it fucks out here, the message is completed! aaaaaa!!!

        } catch (Exception e) {
            //#581 smoking gun should point at the user, NOT at our broker
            this.prepareException(e);
            this.IsFucked = true;
            
        }
        
        //measure side effects after, whether or not there was an exception
        if (Limits.getFutureCalls() > futureCalls) this.HadSideEffects = true;
        if (Limits.getQueueableJobs() > queueableJobs) this.HadSideEffects = true;
        if (Limits.getDMLStatements() > dmlStatements) this.HadSideEffects = true;
        if (Limits.getEmailInvocations() > emailInvocations) this.HadSideEffects = true;
        
        if (this.Message.ExecuteDuration__c == null) this.Message.ExecuteDuration__c = 0;
        this.Message.ExecuteDuration__c += System.now().getTime() - timer;
    }
    
    /**
     * "Restarting" is the synchronous re-attempt of
     * a single message, with the hope of it reprocessing
     * successfully (presumably after changing something)
     *
     * In order to prevent inadvertent replay and keep
     * the message lifecycle correct, we do not allow casual
     * reprocessing of messages unless they Fucked or Killed.
     *
     * Fucked messages and Killed messages SHOULD both have
     * some non-null Exception. While that's not completely
     * guaranteed (we may see some time-out edge case etc)
     * its the most semantic signal we have at the moment.
     *
     * .------------- Messages with an Exception -------------.
     * |                                                      |
     * |   .-- Fucked messages --.   .-- Killed messages -.   |
     * |   |                     |   |                    |   |
     * |   | Status = Started    |   | Status = Completed |   |
     * |   | Exception != null   |   | Exception != null  |   |
     * |   |                     |   |                    |   |
     * |   '---------------------'   '--------------------'   |
     * |                                                      |
     * '------------------------------------------------------'
     *
     * I like to think of "Fucked" and "Killed" messages as both
     * being subsets of the common "Exception" messages.
     *
     * Analogous to how "execute" and "callouts" are both
     * sub-parts of the bigger concept of "invocation"
     *
     * @exception MessageException if you are not allowed to restart the message
     * @return true if synchronous reprocess succeeded, false if it failed
     */
    public void restart() {
        System.assert(false, 'This is JavaScript now.');
    }
    
    public PageReference showRecordData() {
        try {
            Id recordId = (Id)this.Event.get('esb__RecordId');
            SObject recordData = ApexDomain.getById(recordId);
            return new ApexPages.StandardController(recordData).view();
        } catch (Exception e) {
            return null;
        }
    }
    
    public PageReference showApexClass() {
        
        String route = this.message.Step__c;
        
        if (route == null) {
            //failure
            throw new MessageException('This message has no route.');
        }
        
        Step__c step = Step__c.getValues(route);
        
        if (step == null) {
            //failure
            throw new MessageException('This message has no step.');
        }
        
        ApexClass apexClass = new ApexClass(Id = step.ApexClassId__c);
        
        if (apexClass.Id == null) {
            //failure
            throw new MessageException('This message has no process.');
        }
        
        return new ApexPages.StandardController(apexClass).view();
    }
    
    public Boolean isHeartbeat() {
        Map<String,Object> event = (Map<String,Object>)Json.deserializeUntyped(this.Message.Event__c);
        return event.get('__IsHeartbeatProcess') != null;
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
    
}