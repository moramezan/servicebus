/**
 * Queueable job = new Job('Wiretaps', userId);
 * System.enqueueJob(job);
 */
global without sharing class Job implements Process.Plugin, Queueable {
    
    /**
     * Unfortunately we need this constructor for Process.Plugin:
     * "System.TypeException: Job does not have a no-arg constructor"
     * At least if someone tries to enqueueJob() it won't insert messages.
     */
    global Job() {}
    
    /**
     * Per #702 we may as well describe this as a "real" Flow plugin
     * although we're intending to just piggy back the system interface.
     *
     * If someone put this into a real flow, they MUST provide esb__SequenceName
     * and we can at least hand back the esb__QueueableId as some kind of output.
     */
    global Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
        plugin.Name = 'ESB Job';
        plugin.Tag = 'Enterprise Service Bus';
        plugin.Description = 'Enqueue a Job into the Enterprise Service Bus';
        
        plugin.inputParameters = new List<Process.PluginDescribeResult.InputParameter>{
            new Process.PluginDescribeResult.InputParameter('esb__SequenceName', Process.PluginDescribeResult.ParameterType.STRING, true)
        };
        
        plugin.outputParameters = new List<Process.PluginDescribeResult.OutputParameter>{
            new Process.PluginDescribeResult.OutputParameter('esb__QueueableId', Process.PluginDescribeResult.ParameterType.STRING)
        };
        
        return plugin;
    }
    
    /**
     * Per #702 this enables developers to Enqueue into ESB without a compile-time
     * dependency, by leveraging the Process.Plugin system interface.
     *
     * @docs ApiJobMethods.html
     * Secondarily it also DOUBLES as a REAL Process.Plugin that people can use
     * in Visual Flow to get stuff into ESB. (Though they would create a dependency.)
     */
    global Process.PluginResult invoke(Process.PluginRequest request) {
        Map<String,Object> parameters = request.inputParameters;
        Queueable job = new Job(parameters);
        Id queueableId = System.enqueueJob(job);
        
        parameters.put('esb__QueueableId', queueableId);
        return new Process.PluginResult(parameters);
    }
    
    public class JobException extends Exception {}
    
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
     * @docs ApiJobConstructors.html
     * @param sequenceName Name of the sequence the data is destined for.
     * @param dataId    Blob representation of the data the sequence will operate on.
     */
    public Job(String sequenceName, Blob data) {
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
     * @docs ApiJobConstructors.html
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
     * @docs ApiJobConstructors.html
     * @param  injectedParameters a parametrised description of the message data.
     */
    global Job(Map<String,Object> parameters) {
        this(new List<Map<String,Object>>{parameters});
    }
    
    /**
     * A collection of multiple parameterized message descriptions, each of which must at minimum
     * contain esb__SequenceName.
     * 
     * @docs ApiJobConstructors.html
     */
    global Job(List<Map<String,Object>> parameterses) {
        // validate params are supplied:
        if (parameterses == null) {
            throw new Broker.EngineException('Cannot supply a null parameters collection.');
        }
        
        //fetch the custom setting or create an empty one
        BrokerSetting__c setting = BrokerSetting__c.getOrgDefaults();
        if (setting == null) setting = new BrokerSetting__c();
        
        //create the message destined for the 0th step of the chain
        for (Map<String,Object> parameters : parameterses) {
            parameters.putAll(new Map<String,Object>{
                '__Hops' => 0,
                '__EntryPointUuid' => uuidVersionFour(), //#751 formerly __EntryPointGuid, this is ONLY for 'our' use
                '__EntryPointDatetime' => System.now(), //#753 formerly __EventStamp this is ONLY for our framework use
                'esb__EnqueueUserId' => UserInfo.getUserId(), //WE use '__' and THEY use 'esb' per #669
                '__EnqueueUserId' => UserInfo.getUserId()
            });
            
            if (parameters.get('esb__EntryPointUuid') == null) {
                //#751 'they' are allowed to mess with this, eg for replay
                parameters.put('esb__EntryPointUuid', uuidVersionFour());
            }
            
            if (parameters.get('esb__EntryPointDatetime') == null) {
                //#753 processes like Schedule are allowed to mess with this}
                parameters.put('esb__EntryPointDatetime', System.now());
            }
            
            this.messages.add(new Message__c(
                Parameters__c = Json.serializePretty(parameters),
                Status__c = setting.IsPaused__c ? 'Queued' : 'Buffered'
            ));
        }
    }
    
    /**
     * Usually handled within a second or so.
     * NOT TO BE CONFUSED WITH BROKER.EXECUTE
     * 
     * We can't really test System.enqueueJob() because of known issue:
     * https://success.salesforce.com/issues_view?id=a1p300000008XM1AAM
     * 
     * But since we aren't actually doing anything with the QueueableContext
     * this works without startTest/stopTest: new Job(parameters).execute(null)
     */
    public void execute(QueueableContext context) {
        if (context != null) new MessageObjectSet(this.messages).populateQueueableId(context);
        List<Message__c> messages = this.persist();
        
        // #653 don't use a @Future call unless necessary
        if (Broker.impl().isAlreadyRunning()) return;
        
        if (!Test.isRunningTest()) {
            //in real life, usurp sysadmin
            Job.processAsUser();
        } else {
            //in tests, just run the thing
            Job.process();
        }
    }
    
    /**
     * NOT TO BE CONFUSED WITH BROKER.PERSIST
     * Persist, but don't execute yet.
     * (Useful for writing unit tests)
     *
     * This can be used in lieu of Database.insert(message)
     * like this: new Job('Wiretaps', userId).persist()
     * 
     * @return list of persisted output messages
     */
    @TestVisible private List<Message__c> persist() {
        //just in time DML
        List<Message__c> inputs = new List<Message__c>();
        List<Message__c> outputs = this.messages;
        Broker.impl().persist(inputs, outputs);
        return outputs;
    }
    
    /**
     * We MUST ALWAYS prevent more than 1 running broker worker
     * otherwise they will fight over the work to be marked etc.
     *
     * Was formerly Broker.process() but needs to be global now
     * for the sake of running from Execute Anonymous context.
     */
    static global void process() {
        Broker impl = Broker.impl();
        if (impl.isAlreadyRunning()) return;
        // #671 first query locator spends less time in 'Preparing'
        Broker.IsFirstRun = true;
        impl.restartIfWorkPending();
    }
    
    /**
     * When this blows up we throw an unhandled exception in our namespace,
     * we should receive an email and reach out to the customer to debug this!
     *
     * @throws JobException
     */
    @Future(callout=true) static private void processAsUser() {
        // #653 don't use an API call unless necessary
        if (Broker.impl().isAlreadyRunning()) return;
        
        PageReference pr = new PageReference(RemoteSiteSettingController.protocolAndHost + '/services/data/v32.0/tooling/executeAnonymous');
        pr.getParameters().put('anonymousBody', Job.class.getName() + '.process();');
        String endpoint = pr.getUrl();
        
        HttpRequest request = new HttpRequest();
        request.setMethod('GET');
        request.setEndpoint(endpoint);
        request.setHeader('Authorization', 'Bearer ' + OAuthSetting__c.getInstance().AccessToken__c);
        
        // #653 throw unhandled exception in our namespace
        HttpResponse response = new Http().send(request);
        Integer status = response.getStatusCode();
        if (status != 200) throw new JobException(response.getBody());
    }
    
    /**
     * #751 Generates Universally unique identifier Version 4:
     * http://en.wikipedia.org/wiki/Universally_unique_identifier#Version_4_.28random.29
     * Version 4 UUIDs have the form 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
     * where x is any hexadecimal digit and y is one of 8, 9, a, or b
     */
    static public String uuidVersionFour() {
        //gives 32 hexadecimal digits, eg 90a9b3e3541a11cc964557c52e272a14
        String digits = EncodingUtil.convertToHex(Crypto.generateAesKey(128));
        
        //concatenate v4
        String output = ''
            + digits.substring(0, 8) //xxxxxxxx
            + '-'
            + digits.substring(8, 12) //xxxx
            + '-'
            + '4' + digits.substring(12, 16).right(3) //4xxx
            + '-'
            + '8' + digits.substring(16, 20).right(3) //yxxx
            + '-'
            + digits.substring(20, 32) //xxxxxxxxxxxx
        ;
        
        return output;
    }
}