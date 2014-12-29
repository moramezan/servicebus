/**
 * Queueable job = new Job('Wiretaps', userId);
 * System.enqueueJob(job);
 */
global without sharing class Job implements Queueable, Database.AllowsCallouts {
    
    private List<Message__c> messages = new List<Message__c>();
    
    /**
     * Note, I can appreciate it seems these constructors are all crammed together. Sorry
     * for this :( otherwise when chaining constructors it whinges with a compile error:
     * "Call to another constructor must be the first statement in constructor block"
     */
    
    /**
     * Prepares Blob data for processing at the start of a nominated sequence
     * by wrapping the pointer to the data (an id) in a Message object
     * This Persisted Data instance is saved to the database and the Broker is
     * immeadiately invoked threreafter
     *
     * @param sequenceName Name of the sequence the data is destined for.
     * @param dataId    Blob representation of the data the sequence will operate on.
     */
    global Job(String sequenceName, Blob data) {
        this(sequenceName, Database.insert(new Document(
            Name = String.valueOf(Datetime.now().getTime()),
            Body = data,
            FolderId = UserInfo.getUserId(),
            ContentType = 'text/plain',
            Type = 'txt'
        )).getId());
    }
    
    /**
     * Prepares data for processing at the start of a nominated sequence by wrapping the pointer to the data (an id) in a
     * Message object. This Message instance is saved to the database and the Broker is immeadiately
     * invoked if it is not already running.
     *
     * @param sequenceName Name of the sequence the data is destined for.
     * @param dataId    Id of some record that the sequence will operate on.
     */
    global Job(String sequenceName, Id entityId) {
        this(new Map<String,Object>{
            '__SequenceName' => sequenceName,
            '__Position' => 1,
            'esb__Id' => entityId
        });
    }
    
    /**
     * Prepares data (represented a parameters collection) for processing.
     * 
     * The parameters collection should at minimum contain 
     *  - an object Id ("Id")
     *  - a sequence name ("__SequenceName")
     * Failure to provide these parameters in the parameters collection will throw an EngineException
     * 
     * The parameters collection is converted to a Message object. This Message instance is saved 
     * to the database and the Broker is immeadiately invoked if it is not already running.
     *
     * @param  injectedParameters a parametrised description of the message data.
     */
    global Job(Map<String,Object> parameters) {
        this(new List<Map<String,Object>>{parameters});
    }
    
    //sequence and list<parameters>
    global Job(List<Map<String,Object>> parameterses) {
        // validate params are supplied:
        if (parameterses == null) {
            throw new Broker.EngineException('Cannot supply a null parameters collection.');
        }
        
        for (Map<String,Object> parameters : parameterses) if (!parameters.containsKey('__SequenceName')) throw new Broker.EngineException('Mandatory parameter __SequenceName not supplied.');
        for (Map<String,Object> parameters : parameterses) if (!parameters.containsKey('__Position')) throw new Broker.EngineException('Mandatory parameter __Position not supplied.');
        
        //fetch the custom setting or create an empty one
        BrokerSetting__c setting = BrokerSetting__c.getOrgDefaults();
        if (setting == null) setting = new BrokerSetting__c();
        
        //create the message destined for the 0th step of the chain
        for (Map<String,Object> parameters : parameterses) {
            parameters.putAll(new Map<String,Object>{
                '__EntryPointGuid' => Broker.getEntryPointGuid(18),
                '__EnqueueUserId' => UserInfo.getUserId()
            });
            
            this.messages.add(new Message__c(
                Parameters__c = Json.serializePretty(parameters),
                Status__c = setting.IsPaused__c ? 'Queued' : 'Buffered'
            ));
        }
    }
    
    /**
     * Usually handled within a second or so.
     * 
     * We can't really test System.enqueueJob() because of known issue:
     * https://success.salesforce.com/issues_view?id=a1p300000008XM1AAM
     * 
     * But since we aren't actually doing anything with the QueueableContext
     * this works without startTest/stopTest: new Job(parameters).execute(null)
     */
    public void execute(QueueableContext context) {
        //just in time DML
        insert this.messages;
        
        if (!Test.isRunningTest()) defer();
        else Broker.process();
    }
    
    @Future(callout=true) static private void defer() {
        PageReference pr = new PageReference(RemoteSiteSettingController.protocolAndHost + '/services/data/v32.0/tooling/executeAnonymous');
        pr.getParameters().put('anonymousBody', Broker.class.getName() + '.process();');
        String endpoint = pr.getUrl();
        
        HttpRequest request = new HttpRequest();
        request.setMethod('GET');
        request.setEndpoint(endpoint);
        request.setHeader('Authorization', 'Bearer ' + OAuthSetting__c.getInstance().AccessToken__c);
        
        new Http().send(request);
    }
    
}