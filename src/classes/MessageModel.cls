/**
 * Domain layer for Message__c model
 */
public class MessageModel extends ApexDomain.StandardModel {
    
    public class ModelException extends Exception {}
    
    /**
     * #981 help prevent side effects from restart
     * https://github.com/bigassforce/servicebus/issues/981#issuecomment-131665156
     */
    static public Exception RestartException;
    
    /**
     * Event parameters
     */
    public void setEvent(Map<String,Object> event) {
        this.Message.Event__c = Json.serialize(event);
    }
    
    public Map<String,Object> getEvent() {
        return (Map<String,Object>)Json.deserializeUntyped(this.Message.Event__c);
    }
    
    public void setParam(String key, Object param) {
        Map<String,Object> event = (Map<String,Object>)Json.deserializeUntyped(this.Message.Event__c);
        event.put(key, param);
        this.Message.Event__c = Json.serialize(event);
    }
    
    public Object getParam(String key) {
        Map<String,Object> event = (Map<String,Object>)Json.deserializeUntyped(this.Message.Event__c);
        return event.get(key);
    }
    
    public MessageModel(Message__c message) {
        super(message);
        this.Message = message;
    }
    
    static public MessageModel fromId(Id messageId) {
        Message__c message = (Message__c)ApexDomain.getById(messageId);
        return new MessageModel(message);
    }
    
    /**
     * For cast-free convenience
     */
    public Message__c Message;
    
    ApexClassModel ServiceModel;
    
    public void invokeCallout() {
        
        //execution time profiler
        Long timer = System.now().getTime();
        
        try {
            
            Integer hops = (Integer)this.getParam('Hops');
            if (hops >= Broker.MaximumHops) {
                throw new Broker.ServiceException('Maximum hops reached: ' + Broker.MaximumHops); //a la "System.LimitException: Maximum stack depth reached: 1001"
            }
            
            if (this.ServiceModel == null) {
                //doing this later than earlier
                String route = (String)this.getParam('Route');
                this.ServiceModel = ApexClassModel.fromRoute(route);
            }
            
            //do invocation
            this.ServiceModel.invokeCallout(this.getEvent());
            
            //clear any errors off the input message as the LAST thing
            this.Message.Exception__c = null;
            this.Message.Cause__c = null;
            
        } catch (Exception e) {
            //#581 smoking gun should point at the user, NOT at our broker
            RestartException = e;
            this.Message.Exception__c = (e.getTypeName() + ': ' + e.getMessage()).abbreviate(SObjectType.Message__c.Fields.Exception__c.Length);
            this.Message.Cause__c = e.getStackTraceString().abbreviate(SObjectType.Message__c.Fields.Cause__c.Length);
        }
        
        //execution time profiler
        if (this.Message.ExecuteDuration__c == null) this.Message.ExecuteDuration__c = 0;
        this.Message.ExecuteDuration__c += System.now().getTime() - timer;
    }
    
    /**
     * NB we see the side effects code in two places. Both the
     * MessageModel and the ApexClassModel. It's for different
     * reasons.
     *
     * This needs to know side effects for the "savepoint tax".
     * The Service checks side effects to prevent DML in callout etc.
     *
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
            
            Integer hops = (Integer)this.getParam('Hops');
            if (hops >= Broker.MaximumHops) {
                throw new Broker.ServiceException('Maximum hops reached: ' + Broker.MaximumHops); //a la "System.LimitException: Maximum stack depth reached: 1001"
            }
            
            if (this.ServiceModel == null) {
                //doing this later than earlier
                String route = (String)this.getParam('Route');
                this.ServiceModel = ApexClassModel.fromRoute(route);
            }
            
            //do invocation
            List<Map<String,Object>> outputEvents = this.ServiceModel.invokeExecute(this.getEvent());
            
            Integer chunkTotal = (Integer)this.getParam('Range');
            if (chunkTotal != null && chunkTotal + outputEvents.size() + outputMessages.size() > 2000) { //#955 possibly 8000, but headspace
                //#955 we throttle inputs+outputs
                throw new Broker.ServiceException(this.ServiceModel.Reflector.getName() + ': Cannot have more than 2000 events in a single operation. Reduce service Chunks or emit fewer events.'); //#955 possibly 8000, but headspace //a la "System.TypeException: Cannot have more than 10 chunks in a single operation. Please rearrange the data to reduce chunking."
            }
            
            //wrap up results into Messages (new guys should have Position = 0)
            for (Map<String,Object> outputEvent : outputEvents) {
                
                if (outputMessages == null) {
                    //panic, our own fault
                    throw new Broker.ServiceException('MessageModel.invokeExecute must receive REFERENCE to list of output messages.');
                }
                
                outputMessages.add(new Message__c(
                    Event__c = Json.serializePretty(outputEvent),
                    Status__c = 'Buffered',
                    ParentId__c = this.getId()
                ));
            }
            
            //clear any errors off the input message as the LAST thing
            this.Message.Status__c = 'Completed'; //#798
            this.Message.Exception__c = null;
            this.Message.Cause__c = null;

        } catch (Exception e) {
            //#581 smoking gun should point at the user, NOT at our broker
            RestartException = e;
            this.Message.Exception__c = (e.getTypeName() + ': ' + e.getMessage()).abbreviate(SObjectType.Message__c.Fields.Exception__c.Length);
            this.Message.Cause__c = e.getStackTraceString().abbreviate(SObjectType.Message__c.Fields.Cause__c.Length);
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
     * a single message, with the hope of it re doing
     * successfully (presumably after changing something)
     *
     * In order to prevent inadvertent replay and keep
     * the message lifecycle correct, we do not allow casual
     * re doing of messages unless they Fucked or Killed.
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
     * Considering #1139 and #1148 paused messages are restartable.
     *
     * .-------------------- Paused Messages -----------------.
     * |                                                      |
     * |                 .-- Fucked messages --.              |
     * |                 |                     |              |
     * |                 | Status = Paused     |              |
     * |                 | Exception = null    |              |
     * |                 |                     |              |
     * |                 '---------------------'              |
     * |                                                      |
     * '------------------------------------------------------'
     *
     * I like to think of "Fucked" and "Killed" messages as both
     * being subsets of the common "Exception" messages.
     *
     * Analogous to how "execute" and "callouts" are both
     * sub-parts of the bigger concept of "invocation"
     *
     * #1187
     * This is indeed another variation on the Broker. Unlike the Vertical Broker,
     * we dictate a single message to handle. (he does not decide what to consume)
     *
     * And unlike the synchronous broker (mostly used for unit tests), we make no
     * attempt to handle errors, catchable or otherwise. ExecAnonResult has them :)
     *
     * No marking here because we would kill any callouts that follow. We
     * already know that this guy is acting on a started message anyway.
     */
    public void restart() {
        
        //TODO mark without DML? is it even possible for attempts to increment?
        MessageSetModel model = new MessageSetModel(new List<Message__c>{this.Message});
        
        //VALIDATE
        if (!Test.isRunningTest() && Application__c.getOrgDefaults().RunAsUserId__c != UserInfo.getUserId()) throw new ModelException('The configured running user Id=[' + UserInfo.getUserId() + '] is null or invalid');
        if (!(this.Message.Status__c == 'Paused' || this.Message.Exception__c != null)) throw new ModelException('Only Paused or Exception messages can be restarted.');
        
        //EXECUTE
        List<Message__c> outputMessages = model.execute(null);
        
        //PERSIST
        model.persist(outputMessages);
        
        //#981#issuecomment-131670372 prevent side effects (like batch jobs) escaping
        if (RestartException != null) throw RestartException;
        
        //success, restart the REAL broker to carry on with the outputs
        Broker.impl().run();
    }
    
    public PageReference showRecordData() {
        try {
            Id recordId = (Id)this.getParam('RecordId');
            SObject recordData = ApexDomain.getById(recordId);
            return new ApexPages.StandardController(recordData).view();
            
        } catch (ApexDomain.DomainException e) {
            throw new ModelException('Could not show record data: ' + e.getMessage());
        }
    }
    
    /**
     * Takes us to the standard salesforce page for the apex class
     */
    public PageReference showApexClass() {
        try {
            String route = (String)this.getParam('Route');
            ApexClassModel model = ApexClassModel.fromRoute(route);
            ApexClass apexClass = (ApexClass)model.getRecord();
            return new ApexPages.StandardController(apexClass).view();
            
        } catch (Broker.ServiceException e) {
            throw new ModelException('Could not show apex class: ' + e.getMessage());
        }
    }
    
    /**
     * One shots avoid the overhead of starting the broker
     * (callout, start, execute, execute, execute)
     * but fatal exceptions have to be grabbed.
     */
    public void appendJobStatus() {
        
        if (this.Message.Status__c != 'Started') {
            //not in bad state
            return;
        }
        
        if (this.Message.Exception__c != null) {
            //already has exception message
            return;
        }
        
        List<AsyncApexJob> asyncApexJobs = [
            SELECT Id, ExtendedStatus
            FROM AsyncApexJob
            WHERE Id = :this.Message.JobId__c
        ];
        
        if (asyncApexJobs.isEmpty()) {
            //no job information
            return;
        }
        
        this.Message.Exception__c = asyncApexJobs[0].ExtendedStatus;
        
        update this.Message;
    }
}