/**
 * Domain layer for Message__c model
 */
public class MessageModel extends ApexDomain.StandardModel {
    
    /**
     * Event parameters
     */
    public Map<String,Object> Event;
    
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
     * For cast-free convenience
     */
    public Message__c Message;
    
    ApexClassModel Model;
    
    /**
     * This performs actual resolution inside the callout and/or execute method.
     */
    public ApexClassModel resolveApexClassModel() {
        
        String process = (String)this.Event.get('esb__Process');
        
        if (process != null) {
            return new ApexClassModel(Type.forName(process)); //#956 "fire and forget" process without sequences or steps
        }
        
        String route = this.message.Step__c;
        
        if (route == null) {
            throw new Broker.UserException('Message has no step for routing to sequence: ' + this.message.Id); //a la "List has no rows for assignment to SObject"
        }
        
        Step__c step = Step__c.getValues(route);
        
        if (step == null) {
            throw new Broker.UserException('Could not resolve route from message step: ' + route); //a la "Could not resolve field 'Billing Address' from value binding"
        }
        
        String apexClassName = step.ApexClassName__c;
        
        if (apexClassName == null) {
            throw new Broker.UserException('Apex class name cannot be null: ' + route); //a la "Argument cannot be null"
        }
        
        Type reflector = Type.forName(apexClassName);
        
        if (reflector == null) {
            throw new Broker.UserException('Class is invalid or not visible: ' + apexClassName); //a la "Variable is not visible" or "Variable does not exist" or "Dependent class is invalid and needs recompilation"
        }
        
        ApexClassModel model = new ApexClassModel(reflector);
        model.getRecord().Id = step.ApexClassId__c;
        return model;
    }
    
    /**
     * TODO COUNT ANY DMLS
     */
    public void invokeCallout() {
        
        //execution time profiler
        Long timer = System.now().getTime();
        
        try {
            
            Integer hops = (Integer)this.Event.get('__Hops');
            if (hops >= Broker.MaximumHops) {
                throw new Broker.UserException('Maximum hops reached: ' + Broker.MaximumHops); //a la "System.LimitException: Maximum stack depth reached: 1001"
            }
            
            if (this.Model == null) {
                //doing this later than earlier
                this.Model = this.resolveApexClassModel();
            }
            
            //do invocation
            this.Model.invokeCallout(this.Event);
            
            //clear any errors off the input message as the LAST thing
            this.Message.Exception__c = null;
            this.Message.Cause__c = null;
            
        } catch (Exception e) {
            //#581 smoking gun should point at the user, NOT at our broker
            this.Message.Exception__c = e.getMessage().abbreviate(SObjectType.Message__c.Fields.Exception__c.Length);
            this.Message.Cause__c = new ExceptionSerializer(e).getAsString().abbreviate(SObjectType.Message__c.Fields.Cause__c.Length);
        }
        
        //execution time profiler
        if (this.Message.ExecuteDuration__c == null) this.Message.ExecuteDuration__c = 0;
        this.Message.ExecuteDuration__c += System.now().getTime() - timer;
    }
    
    /**
     * TODO COUNT ANY CALLOUTS
     * @return HAD SIDE EFFECTS
     */
    public Boolean invokeExecute(List<Message__c> outputMessages) {
        
        if (this.Message.Exception__c != null) {
            //#864 skip bad guys
            return false;
        }
        
        //execution time profiler
        Long timer = System.now().getTime();
        
        //measure side effects before
        Integer futureCalls = Limits.getFutureCalls();
        Integer queueableJobs = Limits.getQueueableJobs();
        Integer dmlStatements = Limits.getDMLStatements();
        Integer emailInvocations = Limits.getEmailInvocations();
        
        try {
            
            Integer hops = (Integer)this.Event.get('__Hops');
            if (hops >= Broker.MaximumHops) {
                throw new Broker.UserException('Maximum hops reached: ' + Broker.MaximumHops); //a la "System.LimitException: Maximum stack depth reached: 1001"
            }
            
            if (this.Model == null) {
                //doing this later than earlier
                this.Model = this.resolveApexClassModel();
            }
            
            //#856 StepConfig should enter the process instance as an Id
            Step__c step = Step__c.getValues(this.Message.Step__c);
            if (step != null) this.Event.put('esb__StepConfigId', step.ConfigId__c);
            
            //do invocation
            List<Map<String,Object>> outputEvents = this.Model.invokeExecute(this.Event);
            
            Integer chunkTotal = (Integer)this.Event.get('__ChunkTotal');
            if (chunkTotal != null && chunkTotal + outputEvents.size() + outputMessages.size() > 8000) {
                //#955 we throttle inputs+outputs
                throw new Broker.UserException(this.Model.Reflector.getName() + ': Cannot have more than 8000 events in a single operation. Reduce process Limits or emit fewer events.'); //a la "System.TypeException: Cannot have more than 10 chunks in a single operation. Please rearrange the data to reduce chunking."
            }
            
            //wrap up results into Messages (new guys should have Position = 0)
            for (Map<String,Object> outputEvent : outputEvents) {
                
                //increment the position of a bunch of output events
                Integer position = (Integer)outputEvent.get('__Position');
                if (position == null) position = 0;
                outputEvent.put('__Position', ++position);
                //TODO #425 enforce overwrite of __ params?
                
                if (outputMessages == null) {
                    //panic, our own fault
                    throw new Broker.UserException('MessageModel.invokeExecute must receive REFERENCE to list of output messages.');
                }
                
                //TODO #972 alphabetize event parameter json
                outputMessages.add(new Message__c(
                    Event__c = Json.serializePretty(outputEvent),
                    Status__c = 'Buffered'
                ));
            }
            
            //clear any errors off the input message as the LAST thing
            this.Message.Status__c = 'Completed'; //#798
            this.Message.Exception__c = null;
            this.Message.Cause__c = null;

        } catch (Exception e) {
            //#581 smoking gun should point at the user, NOT at our broker
            this.Message.Exception__c = e.getMessage().abbreviate(SObjectType.Message__c.Fields.Exception__c.Length);
            this.Message.Cause__c = new ExceptionSerializer(e).getAsString().abbreviate(SObjectType.Message__c.Fields.Cause__c.Length);
        }
        
        //execution time profiler
        if (this.Message.ExecuteDuration__c == null) this.Message.ExecuteDuration__c = 0;
        this.Message.ExecuteDuration__c += System.now().getTime() - timer;
        
        //measure side effects after, whether or not there was an exception
        if (Limits.getFutureCalls() > futureCalls) return true;
        if (Limits.getQueueableJobs() > queueableJobs) return true;
        if (Limits.getDMLStatements() > dmlStatements) return true;
        if (Limits.getEmailInvocations() > emailInvocations) return true;
        
        //no side effects
        return false;
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
    
    /**
     * Takes us to the standard salesforce page for the apex class
     */
    public PageReference showApexClass() {
        ApexClassModel model = this.resolveApexClassModel();
        ApexClass apexClass = (ApexClass)model.getRecord();
        return new ApexPages.StandardController(apexClass).view();
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