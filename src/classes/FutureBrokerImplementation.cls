/**
 * DO NOT DEFER THIS METHOD EVER
 * see http://salesforce.stackexchange.com/a/24448/320
 *
 * The FutureBroker provides a worker process that pulls a limited number of Messages off the queue. But
 * since he does not have his own 'execute' method contexts like a Batch Job, he relies upon PageReference invocations
 * to branch out more execution contexts. Added complexity, but restart performance tends to be very good, all the time.
 * 
 * This class is WITHOUT SHARING to ensure the process can execute regardless of running user context.
 */
virtual public without sharing class FutureBrokerImplementation extends Broker implements FutureBrokerDispatcher.Restartable {
    
    private String sessionId = UserInfo.getSessionId();
    
    /**
     * Each Broker implementation must provide the smarts of how to restart it.
     * The FutureBroker sequences another @Future invocation to run itself again.
     */
    virtual override public void restartImpl() {
        FutureBrokerDispatcher.restart(UserInfo.getSessionId());
    }
    
    /**
     * We would just LOVE to do new FutureBroker().start() here. But we cannot invoke a @future from a @future context,
     * so we use a Tooling API callout to bust out of the @future context. We cannot do callout from a callin either.
     */
    public void restart(String sessionId) {
        if (BrokerSettings__c.getInstance().Inhibit__c == true) System.assert(false, 'INHIBIT'); //INHIBIT
        
        //the endpoint will be correct because we are in Future Context (pod.salesforce.com)
        //but this session must be set explicitly because we are in Future Context (no session id)
        this.sessionId = sessionId;
        
        String futureBrokerUrl = Page.FutureBroker.getUrl(); //full page name for anonymous context
        String command = 'new PageReference(\'' + futureBrokerUrl + '\').getContent();';
        
        Api.Client client = new Api.Client(sessionId);
        Api.ExecuteAnonymousResult result = client.executeAnonymous(command);
        if (!result.success) throw new BrokerException(result.compileProblem == null ? result.compileProblem : result.exceptionMessage);
    }
    
    virtual public void handle() {
        Id messageId = ApexPages.currentPage().getParameters().get('id');
        if (messageId == null) {
            //using getContent to decouple Tooling API callout
            handleStart();
        } else {
            //using getContent to decouple process invokation
            handleMessage(messageId);
        }
    }
    
    /**
     * So we use PageReference.getContent with an action method to circumvent 'Callout loop not allowed' error. When
     * a FutureBroker is 'started', the mechanics look quite similar to BatchBrokerImplementation in terms of execution contexts.
     * THIS IS NEVER CALLED. Invoked by consequence of 'viewing' the Visualforce Page 'FutureBroker' WITHOUT an Id.
     */
     virtual public void handleStart() {
        //start (MARK)
        Database.QueryLocator locator = this.locateMarkedWork(5); //note that markImpl is called inside this method
        Database.QueryLocatorIterator iterator = locator.iterator();
        
        //execute (EXECUTE, RESOLVE, PERSIST)
        while (iterator.hasNext()) {
            //each in separate execution context
            Message__c message = (Message__c)iterator.next();
            Api.Client client = new Api.Client();
            
            //endpoint must be derived because we are in Visualforce Context (c.pod.visual.force.com)
            client.endpoint_x = this.podProtocolAndHost() + '/services/Soap/T/29.0';
            String futureBrokerUrl = Page.FutureBroker.getUrl(); //full page name for anonymous context
            String command = 'new PageReference(\'' + futureBrokerUrl + '?id=' + message.Id + '\').getContent();'; //EXECUTE
            Api.ExecuteAnonymousResult result = client.executeAnonymous(command);
            if(!result.success) throw new BrokerException(result.compileProblem == null ? result.compileProblem : result.exceptionMessage);
        }
        
        //finish (invokes broker in a @future)
        this.restartIfWorkPending();
    }
    
    /**
     * Similarly, we must circumvent 'Callout loop not allowed error' when a process uses a WebService or HttpRequest by
     * using the Page.getContent trick. We can't just call Broker.executeResolvePersist() using execute anonymous.
     * THIS IS NEVER CALLED. Invoked by consequence of 'viewing' the Visualforce Page 'FutureBroker' WITH an Id.
     */
    virtual public void handleMessage(Id messageId) {
        Broker.executeResolvePersist(messageId);
    }
    
    /**
     * Normally the markImpl just performs DML that sets the 'Processing' status. But in this FutureBroker, we have
     * callouts that follow locateMarkedWork() in the same execution context which would cause uncommitted DML error. So
     * to avoid this, here we provide a 'special' mark implementation to do the DML in a separate Tooling API context.
     */
    virtual override public void markImpl(Set<Id> messageIds) {
        Api.Client client = new Api.Client();
        
        //endpoint must be derived because we are in Visualforce Context (c.pod.visual.force.com)
        client.endpoint_x = this.podProtocolAndHost() + '/services/Soap/T/29.0';
        String brokerClassName = Broker.class.getName(); //full class name for anonymous context
        String command = brokerClassName + '.mark((Set<Id>)Json.deserialize(\'' + Json.serialize(messageIds) + '\', Set<Id>.class));';
        Api.ExecuteAnonymousResult result = client.executeAnonymous(command);
        if (!result.success) throw new BrokerException(result.compileProblem == null ? result.compileProblem : result.exceptionMessage);
    }
    
    override public Boolean isAlreadyRunning() {
        System.Type type = FutureBrokerDispatcher.class;
        String namespacePrefix;
        String name;
        
        if (type.getName().contains('.')) {
            //managed (namespaceprefix.classname)
            namespacePrefix = type.getName().substringBefore('.');
            name = type.getName().substringAfter('.');
        } else {
            //unmanaged (classname)
            namespacePrefix = '';
            name = type.getName();
        }
        
        //find existing futures
        Integer existingFuturesCount = [
            SELECT COUNT()
            FROM AsyncApexJob
            WHERE ApexClass.NamespacePrefix = :namespacePrefix AND ApexClass.Name = :name AND MethodName = 'start'
            AND JobType = 'Future'
            AND Status IN ('Queued', 'Processing', 'Preparing')
        ];
        
        return existingFuturesCount != 0;
    }
    
    public class IdentityResult {
        public String id;
        public String asserted_user;
        public String user_id;
        public String organization_id;
        public String username;
        public String nick_name;
        public String display_name;
        public String email;
        public String first_name;
        public String last_name;
        //public Map<String,Object> status;
        public Map<String,String> photos;
        public Map<String,String> urls;
        public Boolean active;
        public String user_type;
        public String language;
        public String locale;
        public Integer utcOffset;
        public DateTime last_modified_date;
    }
    
    /**
     * eg "https://pod.salesforce.com"
     */
    public String podProtocolAndHost() {
        String orgId = UserInfo.getOrganizationId();
        String userId = UserInfo.getUserId();
        
        System.PageReference pr = new System.PageReference('/id/' + orgId + '/' + userId);
        pr.getParameters().put('oauth_token', this.sessionId);
        pr.getParameters().put('format', 'json');
        
        String data;
        if (!Test.isRunningTest()) {
            //fetch real identity
            data = pr.getContent().toString();
        } else {
            //fake test identity
            data = '{"urls": {"rest": "' + Url.getSalesforceBaseUrl().toExternalForm() + '"}}';
        }
        IdentityResult result = (IdentityResult)Json.deserialize(data, IdentityResult.class);
        
        Url rest = new Url(result.urls.get('rest'));
        String protocolAndHost = rest.getProtocol() + '://' + rest.getHost();
        return protocolAndHost;
    }
}