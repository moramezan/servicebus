/**
 * system.Queueable job = new Job('Wiretaps', userId);
 * System.enqueueJob(job);
 */
global class Job implements Process.Plugin, system.Queueable {
    
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
        
        plugin.InputParameters = new List<Process.PluginDescribeResult.InputParameter>{
            new Process.PluginDescribeResult.InputParameter('esb__RecordId', Process.PluginDescribeResult.ParameterType.ID, true),
            new Process.PluginDescribeResult.InputParameter('esb__SequenceName', Process.PluginDescribeResult.ParameterType.STRING, true)
        };
        
        plugin.OutputParameters = new List<Process.PluginDescribeResult.OutputParameter>{
            new Process.PluginDescribeResult.OutputParameter('esb__QueueableId', Process.PluginDescribeResult.ParameterType.STRING)
        };
        
        return plugin;
    }
    
    /**
     * Per #868 this exists to hold whichever
     * event the Broker currently deals with.
     */
    static public String EventProvider;
    
    /**
     * Per #702 this enables developers to Enqueue into ESB without a compile-time
     * dependency, by leveraging the Process.Plugin system interface.
     *
     * @docs ApiJobClass.html
     * Secondarily it also DOUBLES as a REAL Process.Plugin that people can use
     * in Visual Flow to get stuff into ESB. (Though they would create a dependency.)
     */
    global Process.PluginResult invoke(Process.PluginRequest request) {
        
        //#868 this plugin doubles as an event provider, so we don't create a BS one
        if (request.InputParameters.get('esb__EventProvider') == true) { //specific equality to avoid null object dereference
            Map<String,Object> event = (Map<String,Object>)Json.deserializeUntyped(EventProvider);
            return new Process.PluginResult(event);
        }
        
        Map<String,Object> inputEvent = request.InputParameters;
        system.Queueable job = new Job(inputEvent);
        Id queueableId = System.enqueueJob(job);
        
        inputEvent.put('esb__QueueableId', queueableId);
        return new Process.PluginResult(inputEvent);
    }
    
    /**
     * Wrapper class for enqueue parameters.
     */
    global class SimpleEvent {
        @InvocableVariable(required=true) global Id RecordId;
        @InvocableVariable(required=true) global String SequenceName;
    }
    
    /**
     * Per #736 this enables developers to leverage ESB Jobs inside Process Builder
     * @docs ApiJobClass.html
     */
    @InvocableMethod(label='Enqueue ESB Job') global static List<Id> enqueue(List<SimpleEvent> simpleEvents) {
        List<Id> ids = new List<Id>();
        for (SimpleEvent simpleEvent : simpleEvents) {
            Map<String,Object> inputEvent = new Map<String,Object>{
                'esb__RecordId' => simpleEvent.RecordId,
                'esb__SequenceName' => simpleEvent.SequenceName
            };
            Job j = new Job(inputEvent);
            Id queueableId = System.enqueueJob(j);
            ids.add(queueableId);
        }
        return ids;
    }
    
    public class RunException extends Exception {}
    public class EnqueueException extends Exception {}
    
    @TestVisible private List<Map<String,Object>> Events = new List<Map<String,Object>>();
    
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
    global Job(String sequenceName, Id recordId) {
        this(new Map<String,Object>{
            'esb__SequenceName' => sequenceName,
            'esb__RecordId' => recordId
        });
    }
    
    /**
     * Prepares data (represented an input event) for processing.
     *
     * The input event collection should at minimum contain
     *  - an object Id ("Id")
     *  - a sequence name ("__SequenceName")
     * Failure to provide these event parameters in the collection will throw an exception
     *
     * The input event collection is converted to a Message object. This Message instance is saved
     * to the database and the Broker is immeadiately invoked if it is not already running.
     *
     * @docs ApiJobConstructors.html
     * @param  injectedParameters a parametrised description of the event.
     */
    global Job(Map<String,Object> inputEvent) {
        this(new List<Map<String,Object>>{inputEvent});
    }
    
    //TODO Job(reflector, inputEvent)
    //TODO Job(reflector, inputEvents)
    
    /**
     * A collection of multiple parameterized message descriptions, each of which must at minimum
     * contain esb__SequenceName.
     *
     * @docs ApiJobConstructors.html
     */
    global Job(List<Map<String,Object>> inputEvents) {
        
        if (inputEvents == null) {
            //failure, bad input collection
            throw new EnqueueException('Enqueued events cannot be null');
        }
        
        if (inputEvents.size() > 10000) {
            //#955 blow up too many input events enqueued
            throw new EnqueueException('Too many events: ' + inputEvents.size());
        }
        
        try {Json.serialize(inputEvents);} catch (JsonException e) {
            //#977 detect unpersistable types
            throw new EnqueueException(e.getMessage());
        }
        
        for (Map<String,Object> inputEvent : inputEvents) {
            
            if (inputEvent == null) {
                //failure, one bad input event
                throw new EnqueueException('Enqueued event cannot be null'); //a la System.NullPointerException: Argument cannot be null
            }
            
            inputEvent.putAll(new Map<String,Object>{
                '__Hops' => 1,
                '__EntryPointUuid' => uuidVersionFour(), //#751 formerly __EntryPointGuid, this is ONLY for 'our' use
                '__EntryPointDatetime' => System.now(), //#753 formerly __EventStamp this is ONLY for our framework use
                'esb__EnqueueUserId' => (Id)UserInfo.getUserId(), //WE use '__' and THEY use 'esb' per #669
                '__EnqueueUserId' => UserInfo.getUserId()
            });
            
            if (inputEvent.get('esb__EntryPointUuid') == null) {
                //#751 'they' are allowed to mess with this, eg for replay
                inputEvent.put('esb__EntryPointUuid', uuidVersionFour());
            }
            
            if (inputEvent.get('esb__EntryPointDatetime') == null) {
                //#753 processes like Heartbeat are allowed to mess with this}
                inputEvent.put('esb__EntryPointDatetime', System.now());
            }
        }
        
        this.Events = inputEvents;
    }
    
    /**
     * Usually handled within a second or so.
     * NOT TO BE CONFUSED WITH BROKER.EXECUTE
     *
     * We can't really test System.enqueueJob() because of known issue:
     * https://success.salesforce.com/issues_view?id=a1p300000008XM1AAM
     *
     * But since we aren't actually doing anything with the QueueableContext
     * this works without startTest/stopTest: new Job(inputEvent).execute(null)
     *
     * #816 https://cloud.githubusercontent.com/assets/1878631/6813469/15c4d956-d27e-11e4-9d3d-e7026e95eade.jpg
     */
    public void execute(QueueableContext context) {
        List<Message__c> messages = new List<Message__c>();
        
        //one strategy to reduce heap size during runtime is to
        //remove items from the collection as you iterate over it
        for (Integer i = 0; i < this.Events.size(); i++) {
            
            /**
             * #694 puts QueueableContext Job Id on messages. Because when people
             * use System.enqueueJob to enqueue a message into the system, they will
             * never get a Message Id. But at least we have a possibility of using
             * the Queueable AsyncApexJob Id as a correlation later for Capture etc.
             */
            if (context != null) {
                Id queueableId = context.getJobId();
                this.Events[i].put('__QueueableId', queueableId);
            }
            
            /**
             * In #658 we hoped to expose esb__SequenceName API in Broker.persist() but
             * it meant we can't insert messages then just 'run' broker over them. Further
             * issue #677 feels like we probably shouldn't be inserting messages at all.
             * We want to interpret esb__SequenceName into __SequenceName and __Position
             * as late and as simply as possible. Doing it here in the execute works OK.
             */
            if (this.Events[i].get('esb__SequenceName') != null) {
                this.Events[i].put('__SequenceName', this.Events[i].get('esb__SequenceName'));
                this.Events[i].put('__Position', 1);
                this.Events[i].put('esb__SequenceName', null);
            }
            
            messages.add(new Message__c(
                Event__c = Json.serializePretty(this.Events[i]),
                Status__c = BrokerSetting__c.getOrgDefaults().IsPaused__c ? 'Paused' : 'Buffered'
            ));
            
            //salesforce does not have iterator.remove() method like java
            //but don't use list.remove(i) that just fucks every odd one!
            this.Events[i] = null;
        }
        
        //just in time DML
        MessageSetModel.Inhibit = false;
        insert messages; //#836
        MessageSetModel.Inhibit = true;
        
        //#653 don't waste FUTURE ASYNC CALL unnecessarily
        if (Test.isRunningTest()) return;
        if (isScheduled()) return;
        if (isRunning()) return;
        
        //#989 optimize already correct running user context
        if (isRunningUser()) run(null); else runAsUser();
    }
    
    static public Boolean isRunningUser() {
        Id userId = UserInfo.getUserId();
        Id runningId = OAuthSetting__c.getOrgDefaults().RunningUserId__c;
        return userId == runningId;
    }
    
    static public Boolean isScheduled() {
        List<CronJobDetail> cronJobDetails = [
            SELECT Id
            FROM CronJobDetail
            WHERE Name = 'Enterprise Service Bus Broker'
            LIMIT 1
        ];
        
        return !cronJobDetails.isEmpty();
    }
    
    static public Boolean isRunning() {
        List<AsyncApexJob> asyncApexJobs = [
            SELECT Id
            FROM AsyncApexJob
            WHERE JobType = 'BatchApex'
            AND ApexClass.Name = 'VerticalBrokerDispatcher'
            AND ApexClass.NamespacePrefix = :NamespaceSetting__c.getOrgDefaults().Prefix__c
            AND Status IN ('Holding', 'Queued', 'Processing', 'Preparing')
            LIMIT 1
        ];
        
        return !asyncApexJobs.isEmpty();
    }
    
    /**
     * When this blows up we throw an unhandled exception in our namespace,
     * we should receive an email and reach out to the customer to debug this!
     *
     * This guy will sometimes throw exceptions from bad ExecAnon result. It
     * is due to the callout failing to schedule the batch because of #929
     * System.UnexpectedException:
     * common.exception.SqlDupValOnIndexException:
     * ORA-00001: unique constraint (CORE.AKCRON_JOB_DETAIL) violated
     *
     * @throws RunException
     */
    @Future(callout=true) static public void runAsUser() {
        //#653 don't waste TOOLING API CALL unnecessarily
        if (isScheduled()) return;
        if (isRunning()) return;
        
        String command = Job.class.getName() + '.run(null);';
        ExecAnonResult result = execAnon(command);
        if (!result.success) throw new RunException(Json.serialize(result)); //#858 don't swallow exceptions
    }
    
    /**
     * Was formerly Broker.run() but needs to be global now
     * for the sake of running from Execute Anonymous context.
     * The "runAsUser" method needs to be able to call this.
     *
     * I think we had 8 global things in Job and 1 in Broker
     * Lets just have 9 global things in Job, and this proxies?
     *
     * We MUST ALWAYS prevent more than 1 running broker worker
     * otherwise they will fight over the work to be marked etc.
     */
    static global void run(Id strategy) {
        //obfuscation of "messageId"
        if (strategy != null) {
            /**
             * This is indeed another variation on the Broker. Unlike the Vertical Broker,
             * we dictate a single message to handle. (he does not decide what to consume)
             *
             * And unlike the synchronous broker (mostly used for unit tests), we make no
             * attempt to handle errors, catchable or otherwise. ExecAnonResult has them :)
             *
             * No marking here because we would kill any callouts that follow. We
             * already know that this guy is acting on a started message anyway.
             */
            //VALIDATE
            Message__c message = (Message__c)ApexDomain.getById(strategy);
            if (message.Exception__c == null) return; //Only messages with an Exception can be restarted
            
            //EXECUTE
            List<Message__c> outputMessages = new List<Message__c>();
            Broker.impl().execute(new List<Message__c>{message}, outputMessages);
            
            //PERSIST
            List<Message__c> inputAndOutputMessages = new List<Message__c>();
            inputAndOutputMessages.add(message);
            inputAndOutputMessages.addAll(outputMessages);
            Broker.impl().persist(inputAndOutputMessages);
            
            //#981#issuecomment-131670372 prevent side effects (like batch jobs) escaping
            if (MessageModel.RestartException != null) throw MessageModel.RestartException;
        }
        
        //success, restart the REAL broker to carry on with the outputs
        if (isScheduled()) return;
        if (isRunning()) return;
        Broker.impl().run();
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
    
    /**
     * {
     *     "line": 534,
     *     "column": 1,
     *     "compiled": true,
     *     "success": false,
     *     "compileProblem": null,
     *     "exceptionStackTrace": "Class.Broker: line 534, column 1\nClass.Job.RunOneBroker.runImpl: line 282, column 1\nClass.Job.runOne: line 296, column 1\nAnonymousBlock: line 1, column 1\nCaused by\nClass.Fuckup.toString: line 10, column 1\nClass.Broker.Wrapper.invokeMain: line 340, column 1\nClass.Broker: line 529, column 1\nClass.Job.RunOneBroker.runImpl: line 282, column 1\nClass.Job.runOne: line 296, column 1\nAnonymousBlock: line 1, column 1",
     *     "exceptionMessage": "System.AssertException: Kablam again"
     * }
     */
    public class ExecAnonResult {
        public Integer line;
        public Integer column;
        public Boolean compiled;
        public Boolean success;
        public String compileProblem;
        public String exceptionStackTrace;
        public String exceptionMessage;
    }
    
    static public ExecAnonResult execAnon(String command) {
        PageReference pr = new PageReference(OAuthSetting__c.getOrgDefaults().InstanceUrl__c + '/services/data/v34.0/tooling/executeAnonymous');
        pr.getParameters().put('anonymousBody', command);
        String endpoint = pr.getUrl();
        
        HttpRequest request = new HttpRequest();
        request.setTimeout(120000);
        request.setMethod('GET');
        request.setEndpoint(endpoint);
        request.setHeader('Authorization', 'Bearer ' + OAuthSetting__c.getOrgDefaults().AccessToken__c);
        
        // #653 throw unhandled exception in our namespace
        HttpResponse response = new Http().send(request);
        Integer status = response.getStatusCode();
        if (status != 200) throw new RunException(response.getBody());
        
        ExecAnonResult result = (ExecAnonResult)Json.deserialize(response.getBody(), ExecAnonResult.class);
        return result;
    }
}