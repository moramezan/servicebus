/**
 * The FutureBroker also provides a worker process that pulls a limited number of Messages off the queue. But
 * since he does not have his own 'execute' method contexts like a Batch Job, he relies upon callouts to the Tooling API
 * to branch out more execution contexts. Added complexity, but restart performance tends to be very good, all the time.
 */
virtual public class FutureBroker extends Broker {
    
    private String toolingEndpoint;
    
    public FutureBroker() {
        this.toolingEndpoint= this.podProtocolAndHost() + '/services/Soap/T/29.0';
    }
    
    /**
     * Each Broker implementation must provide the smarts of how to restart it.
     * The FutureBroker sequences another @Future invocation to run itself again.
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
            client.endpoint_x = this.toolingEndpoint;
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
        client.endpoint_x = this.toolingEndpoint;
        String brokerClassName = Broker.class.getName(); //full class name for anonymous context
        String command = brokerClassName + '.mark((Set<Id>)Json.deserialize(\'' + Json.serialize(messageIds) + '\', Set<Id>.class));';
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
        pr.getParameters().put('oauth_token', UserInfo.getSessionId());
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