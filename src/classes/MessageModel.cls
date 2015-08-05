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
     * Profiler mark
     */
    public void start() {
        this.Start = System.now().getTime();
    }
    
    /**
     * Profiler unmark
     */
    public void finish() {
        Long start = this.Start;
        Long finish = System.now().getTime();
        Long duration = finish - start;
        
        if (this.Message.ExecuteDuration__c == null) this.Message.ExecuteDuration__c = 0;
        this.Message.ExecuteDuration__c += duration;
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
        
        Integer hops = (Integer)this.Event.get('__Hops');
        
        if (hops >= Broker.MaxHops) {
            MessageException e = new MessageException('Too many hops - to resolve, manually set __Hops on event parameters to 0');
            this.prepareException(e);
            throw e;
        }
        
        if (this.Process != null) {
            //success, nothing to do as already prepared
            return;
        }
        
        String route = this.message.Step__c;
        
        if (route == null) {
            MessageException e = new MessageException('This message has no route: ' + this.message.Id);
            this.prepareException(e);
            throw e;
        }
        
        Step__c step = Step__c.getValues(route);
        
        if (step == null) {
            MessageException e = new MessageException('Nonexistent route, eg bad sequence name, position, missing terminate: ' + route);
            this.prepareException(e);
            throw e;
        }
        
        String apexClassName = step.ApexClassName__c;
        
        if (apexClassName == null) {
            MessageException e = new MessageException('Step fully qualified class name was null: ' + step.Id);
            this.prepareException(e);
            throw e;
        }
        
        Type reflector = Type.forName(apexClassName);
        
        if (reflector == null) {
            MessageException e = new MessageException('Reflector for classname was null: ' + apexClassName);
            this.prepareException(e);
            throw e;
        }
        
        this.Process = reflector.newInstance();
    }
    
    /**
     * TODO COUNT ANY DMLS
     */
    public void invokeCallouts() {
        
        Boolean hadException = false;
        
        try {
            //profiler
            this.start();
            
            //instantiate if needed
            this.prepareProcess();
            
            //provide input event and set flag
            Job.Event = this.Event.clone();
            Job.Event.put('esb__AllowsCallouts', true);
            
            //do callouts
            String data = String.valueOf(process);
            if (data != null) {
                MessageException e = new MessageException('Your AllowsCallouts code block should return null.');
                this.prepareException(e);
                throw e;
            }
            
        } catch (Exception e) {
            //smoking gun should point at user
            this.prepareException(e);
            hadException = true;
            
        } finally {
            //profiler
            this.finish();
            
        }
        
        if (hadException) throw new MessageException('Callouts exception in message model.');
    }
    
    /**
     * TODO COUNT ANY CALLOUTS
     */
    public void invokeExecute(List<Message__c> outputMessages) {
        
        Boolean hadException = false;
        
        try {
            //profiler
            this.start();
            
            //instantiate if needed
            this.prepareProcess();
            
            //provide input event and set flag
            Job.Event = this.Event.clone();
            Job.Event.put('esb__AllowsCallouts', false);
            
            //#877 surface SessionId to select few orgs and packages
            //Boolean allowSessionId = Broker.isAllowedSessionId(this.Message.ApexClassName__c, UserInfo.getOrganizationId());
            //if (allowSessionId) Job.Event.put('__SessionId', OAuthSetting__c.getInstance().AccessToken__c);
            //TODO for #886
            
            //do invocation
            String data = String.valueOf(process);
            if (data == null) {
                MessageException e = new MessageException('Your main code block should return a serialized List<Map<String,Object>>.');
                this.prepareException(e);
                throw e;
            }
            
            //TODO for #886
            //if (data.endsWith(this.Message.ApexClassName__c.replaceAll('[^.]+\\.', '') + ':[]')) {
                //MessageException e = new MessageException('Your plugin has not overridden the toString() method. Please refer to the Process Developers Guide for specific guidance.');
                //this.prepareException(e);
                //throw e;
            //}
            
            //output no longer equals balance plus delta
            
            //clear any errors off the record
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
            hadException = true;
            
        } finally {
            //profiler
            this.finish();
        }
        
        if (hadException) throw new MessageException('Execute exception in message model.');
    }
    
    public void setApexClassName(Type reflector) {
        String apexClassName = reflector.getName();
        this.Message.ApexClassName__c = apexClassName;
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
    public Boolean restart() {
        
        if (this.Message.Exception__c == null) {
            //prevent inadvertent replay! yeah, we are not even looking at Status...
            throw new MessageException('Only messages with an Exception can be restarted.');
        }
        
        //do special run once broker
        Boolean result = Job.runOneAsUser(message.Id);
        
        if (!result) {
            //stop here and return
            return false;
        }
        
        //success, restart the REAL broker to carry on with the outputs
        Job.runAsUser();
        
        return true;
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
    
}