/**
 * Domain layer for Message__c model
 */
public with sharing class MessageModel extends ApexDomain.StandardModel {
    
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
        this.Message.Cause__c = new Broker.ExceptionSerializer(e).getAsString().abbreviate(SObjectType.Message__c.Fields.Cause__c.Length);
    }
    
    /**
     * For execution duration profiling
     */
    private Long Start;
    
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
            
            Type reflector = Type.forName(apexClassName);
            
            if (reflector == null) {
                throw new MessageException('Reflector for classname was null: ' + apexClassName);
            }
            
            this.Process = reflector.newInstance();
            
        } catch (Exception e) {
            this.prepareException(e);
            this.IsFucked = true;
        }
    }
    
    /**
     * TODO COUNT ANY DMLS
     */
    public void invokeCallouts() {
        Long start = System.now().getTime();
        
        try {
            //skip bad guys
            if (this.IsFucked) return;
            
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
        
        this.Message.ExecuteDuration__c += System.now().getTime() - start;
    }
    
    /**
     * TODO COUNT ANY CALLOUTS
     */
    public void invokeExecute(List<Message__c> outputMessages) {
        Long start = System.now().getTime();
        
        //measure side effects before
        Integer queueables = Limits.getQueueableJobs();
        Integer futures = Limits.getFutureCalls();
        Integer emails = Limits.getEmailInvocations();
        Integer dmls = Limits.getDMLStatements();
        
        try {
            //skip bad guys
            if (this.IsFucked) return;
            
            //provide input event and set flag
            Job.Event = this.Event.clone();
            Job.Event.put('esb__AllowsCallouts', false);
            
            //#877 surface SessionId to select few orgs and packages
            //Boolean allowSessionId = Broker.isAllowedSessionId(step.ApexClassName__c, UserInfo.getOrganizationId());
            //if (allowSessionId) Job.Event.put('__SessionId', OAuthSetting__c.getOrgDefaults().AccessToken__c);
            //TODO for #886
            
            //do invocation
            String data = String.valueOf(process);
            if (data == null) throw new MessageException('Your main code block should return a List<Map<String,Object>>.');
            
            //TODO for #886
            //if (data.endsWith(step.ApexClassName__c.replaceAll('[^.]+\\.', '') + ':[]')) {
                //MessageException e = new MessageException('Your plugin has not overridden the toString() method. Please refer to the Process Developers Guide for specific guidance.');
                //this.prepareException(e);
                //throw e;
            //}
            
            //clear any errors off the input message
            this.Message.Status__c = 'Completed'; //#798
            this.Message.Exception__c = null;
            this.Message.Cause__c = null;
            
            //wrap up results into Messages (new guys should have Position = 0)
            List<Object> outputEvents = (List<Object>)Json.deserializeUntyped(data);
            
            for (Object outputEvent : outputEvents) {
                outputMessages.add(new Message__c(
                    Event__c = Json.serializePretty(outputEvent),
                    Status__c = 'Buffered'
                ));
            }

        } catch (Exception e) {
            //#581 smoking gun should point at the user, NOT at our broker
            this.prepareException(e);
            this.IsFucked = true;
        }
        
        //measure side effects after, whether or not there was an exception
        if (Limits.getEmailInvocations() > emails) this.HadSideEffects = true;
        if (Limits.getQueueableJobs() > queueables) this.HadSideEffects = true;
        if (Limits.getDMLStatements() > dmls) this.HadSideEffects = true;
        if (Limits.getFutureCalls() > futures) this.HadSideEffects = true;
        
        this.Message.ExecuteDuration__c += System.now().getTime() - start;
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
    
}