/**
 * The FutureBroker also provides a worker process that pulls a limited number of Messages off the queue. But
 * since he does not have his own 'execute' method contexts like a Batch Job, he relies upon callouts to the Tooling API
 * to branch out more execution contexts. Added complexity, but restart performance tends to be very good, all the time.
 */
virtual public class FutureBroker extends Broker {
    
    /**
     * Each Broker implementation must provide the smarts of how to restart it.
     * The FutureBroker chains another @Future invocation to run itself again.
     */
    virtual override public void restartImpl() {
        FutureBroker.restart(UserInfo.getSessionId());
    }
    
    /**
     * We would just LOVE to do new FutureBroker().start() here. But we cannot invoke a @future from a @future context,
     * so we use a Tooling API callout to bust out of the @future context. We cannot do callout from a callin either.
     */
    @future(callout=true) static private void restart(String sessionId) {
        if (BrokerSettings__c.getInstance().Inhibit__c == true) System.assert(false, 'INHIBIT'); //INHIBIT
        
        String futureBrokerUrl = Page.FutureBroker.getUrl(); //full page name for anonymous context
        String command = 'new PageReference(\'' + futureBrokerUrl + '\').getContent();';
        
        Api.Client client = new Api.Client(sessionId);
        Api.ExecuteAnonymousResult result = client.executeAnonymous(command);
        if (!result.success) throw new BrokerException(result.compileProblem == null ? result.compileProblem : result.exceptionMessage);
    }
    
    /**
     * So we use PageReference.getContent with an action method to circumvent 'Callout loop not allowed' error. When
     * a FutureBroker is 'started', the mechanics look quite similar to BatchBroker in terms of execution contexts.
     * THIS IS NEVER CALLED. Invoked by conposition of 'viewing' the Visualforce Page 'FutureBroker'.
     */
    virtual public void start() {
        //start (MARK)
        Database.QueryLocator locator = this.locateMarkedWork(5); //note that markImpl is called inside this method
        Database.QueryLocatorIterator iterator = locator.iterator();
        
        //execute (EXECUTE, RESOLVE, PERSIST)
        while (iterator.hasNext()) {
            //each in separate execution context
            Message__c message = (Message__c)iterator.next();
            Api.Client client = new Api.Client();
            client.endpoint_x = 'https://eu2.salesforce.com/services/Soap/T/29.0';
            String command = 'Broker.executeResolvePersist(\'' + message.Id + '\');'; //EXECUTE
            Api.ExecuteAnonymousResult result = client.executeAnonymous(command);
            if(!result.success) throw new BrokerException(result.compileProblem == null ? result.compileProblem : result.exceptionMessage);
        }
        
        //finish (invokes broker in a @future)
        this.restartIfWorkPending();
    }
    
    /**
     * Normally the markImpl just performs DML that sets the 'Processing' status. But in this FutureBroker, we have
     * callouts that follow locateMarkedWork() in the same execution context which would cause uncommitted DML error. So
     * to avoid this, here we provide a 'special' mark implementation to do the DML in a separate Tooling API context.
     */
    virtual override public void markImpl(Set<Id> messageIds) {
        Api.Client client = new Api.Client();
        client.endpoint_x = 'https://eu2.salesforce.com/services/Soap/T/29.0';
        String command = 'Broker.mark((Set<Id>)Json.deserialize(\'' + Json.serialize(messageIds) + '\', Set<Id>.class));';
        Api.ExecuteAnonymousResult result = client.executeAnonymous(command);
        if (!result.success) throw new BrokerException(result.compileProblem == null ? result.compileProblem : result.exceptionMessage);
    }
    
    override public Boolean isAlreadyRunning() {
        System.Type type = FutureBroker.class;
        String namespacePrefix;
        String name;
        
        if (type.getName().contains('.')) {
            //managed (namespaceprefix.classname)
            name = type.getName().substringBefore('.');
            namespacePrefix = type.getName().substringAfter('.');
        } else {
            //unmanaged (classname)
            name = type.getName();
            namespacePrefix = '';
        }
        
        //find existing futures
        List<AsyncApexJob> existingFutures = [
            SELECT ApexClassId, JobType
            FROM AsyncApexJob
            WHERE ApexClass.NamespacePrefix = :namespacePrefix AND ApexClass.Name = :name AND MethodName = 'start'
            AND JobType = 'Future'
            AND Status IN ('Queued', 'Processing', 'Preparing')
        ];
        
        return !existingFutures.isEmpty();
    }
    
}