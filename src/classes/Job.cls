/**
 * system.Queueable job = new Job('Wiretaps', userId);
 * System.enqueueJob(job);
 */
global class Job implements Process.Plugin, system.Queueable {
    
    /**
     * We use this legitimately to "Wakeup" in rebuffer etc
     * But this constructor has to be public for Process.Plugin:
     * "System.TypeException: Job does not have a no-arg constructor"
     */
    global Job() {}
    
    /**
     * Per #702 we may as well describe this as a "real" Flow plugin
     * although we're intending to just piggy back the system interface.
     *
     * If someone put this into a real flow, they MUST provide Sequence
     * and we can at least hand back the JobId as some kind of output.
     */
    global Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
        plugin.Name = 'Enqueue Service Bus Job';
        plugin.Tag = 'Enterprise Service Bus';
        plugin.Description = 'Enqueue a Job into the Enterprise Service Bus';
        
        plugin.InputParameters = new List<Process.PluginDescribeResult.InputParameter>{
            new Process.PluginDescribeResult.InputParameter('RecordId', Process.PluginDescribeResult.ParameterType.ID, true),
            new Process.PluginDescribeResult.InputParameter('ToSequence', Process.PluginDescribeResult.ParameterType.STRING, true),
            new Process.PluginDescribeResult.InputParameter('ToProcess', Process.PluginDescribeResult.ParameterType.STRING, true),
            new Process.PluginDescribeResult.InputParameter('ToConfig', Process.PluginDescribeResult.ParameterType.ID, true)
        };
        
        plugin.OutputParameters = new List<Process.PluginDescribeResult.OutputParameter>{
            new Process.PluginDescribeResult.OutputParameter('JobId', Process.PluginDescribeResult.ParameterType.STRING)
        };
        
        return plugin;
    }
    
    /**
     * Per #702 this enables developers to Enqueue into Service Bus without a compile-time
     * dependency, by leveraging the Process.Plugin system interface.
     *
     * @docs ApiJobClass.html
     * Secondarily it also DOUBLES as a REAL Process.Plugin that people can use
     * in Visual Flow to get stuff into Service Bus. (Though they would create a dependency.)
     */
    global Process.PluginResult invoke(Process.PluginRequest request) {
        Map<String,Object> inputEvent = request.InputParameters;
        system.Queueable job = new Job(inputEvent);
        Id jobId = System.enqueueJob(job);
        
        inputEvent.put('JobId', jobId);
        return new Process.PluginResult(inputEvent);
    }
    
    /**
     * Wrapper class for enqueue parameters.
     */
    global class SimpleEvent {
        @InvocableVariable(required=true) global Id RecordId;
        @InvocableVariable(required=true) global String ToSequence;
        //@InvocableVariable(required=true) global String ToProcess;
        //@InvocableVariable(required=true) global String ToConfig;
    }
    
    /**
     * Per #736 this enables developers to leverage Service Bus Jobs inside Process Builder
     * @docs ApiJobClass.html
     */
    @InvocableMethod(label='Enqueue Service Bus Job') global static List<Id> enqueue(List<SimpleEvent> simpleEvents) {
        List<Id> ids = new List<Id>();
        for (SimpleEvent simpleEvent : simpleEvents) {
            Map<String,Object> inputEvent = new Map<String,Object>{
                'ToSequence' => simpleEvent.ToSequence,
                //'ToProcess' => simpleEvent.ToProcess,
                //'ToConfig' => simpleEvent.ToConfig
                'RecordId' => simpleEvent.RecordId
            };
            Job job = new Job(inputEvent);
            Id jobId = System.enqueueJob(job);
            ids.add(jobId);
        }
        return ids;
    }
    
    public class RunException extends Exception {}
    public class EnqueueException extends Exception {}
    
    public List<Map<String,Object>> Events = new List<Map<String,Object>>();
    
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
    public Job(String sequenceName, Id recordId) {
        //TODO could this become Route to accommodate either/or, by detecting the difference somehow?
        this(new Map<String,Object>{
            'ToSequence' => sequenceName,
            //'ToProcess' => sequenceName,
            //'ToConfig' => sequenceName,
            'RecordId' => recordId
        });
    }
    
    /**
     * Prepares data (represented an input event) for processing.
     *
     * The input event collection should at minimum contain
     *  - an object Id ("Id")
     *  - a sequence ("ToSequence") or a process ("ToProcess") or a config ("ToConfig")
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
     * contain Sequence.
     *
     * @docs ApiJobConstructors.html
     */
    global Job(List<Map<String,Object>> inputEvents) {
        
        if (inputEvents == null) {
            //failure, bad input collection
            throw new EnqueueException('Enqueued events cannot be null');
        }
        
        if (inputEvents.size() > 1000) { //#955 possibly 10000, but headspace
            //#955 blow up too many input events enqueued
            throw new EnqueueException('Too many events: ' + inputEvents.size());
        }
        
        try {Json.serialize(inputEvents);} catch (JsonException e) {
            //#977 detect unpersistable types
            throw new EnqueueException(e.getMessage());
        }
        
        Set<String> legalKeys = new Set<String>{
            'EnqueuedById',
            'EntryPointTimestamp',
            'EntryPointUuid',
            'JobId',
            'MessageId',
            'RecordId',
            'ToSequence',
            'ToProcess',
            'ToConfig',
            //'Route', //TODO confirm if this disallowed
            'Hops'
        };
        
        //#999 allow third-parties to "enqueue to config"
        Map<String,String> config2sequence = new Map<String,String>();
        for (Step__c step : Step__c.getAll().values()) config2sequence.put(step.ConfigId__c, step.SequenceName__c);
        
        for (Map<String,Object> input : inputEvents) {
            
            if (input == null) {
                //failure, one bad input event
                throw new EnqueueException('Enqueued event cannot be null'); //a la System.NullPointerException: Argument cannot be null
            }
            
            Map<String,Object> inputEvent = input.clone();
            
            for (String key : inputEvent.keySet()) {
                
                if (legalKeys.contains(key)) {
                    //success, basically our api
                    continue; //ok
                }
                
                if (key.startsWith('__')) {
                    //failure, reserved for us
                    throw new EnqueueException('Namespace \'__\' is not supported. If you are attempting to use a custom event parameter, be sure to prepend the \'c__\' before the parameter name.'); //a la //sObject type 'Messsss' is not supported. If you are attempting to use a custom object, be sure to append the '__c' after the entity name. Please reference your WSDL or the describe call for the appropriate names.
                }
                
                if (!key.contains('__')) {
                    //failure, namespace is required
                    throw new EnqueueException('Namespace \'' + key + '\' is not supported. If you are attempting to use a custom event parameter, be sure to prepend the \'c__\' before the parameter name.'); //a la //sObject type 'Messsss' is not supported. If you are attempting to use a custom object, be sure to append the '__c' after the entity name. Please reference your WSDL or the describe call for the appropriate names.
                }
            }
            
            //#999 enqueue routing helpers
            String toSequence = (String)inputEvent.get('ToSequence');
            String toProcess = (String)inputEvent.get('ToProcess');
            String toConfig = (String)inputEvent.get('ToConfig');
            
            if (toSequence != null) {
                //converts sequence to route
                inputEvent.remove('ToSequence');
                inputEvent.put('__ToSequence', toSequence);
                inputEvent.put('Route', toSequence + '#' + '0');
            }
            
            if (toProcess != null) {
                //converts process to route
                inputEvent.remove('ToProcess');
                inputEvent.put('__ToProcess', toProcess);
                inputEvent.put('Route', toProcess);
                
            }
            
            if (toConfig != null) {
                //converts config to route
                inputEvent.remove('ToConfig');
                inputEvent.put('__ToConfig', toConfig);
                inputEvent.put('Route', config2sequence.get((String)toConfig) + '#' + '0');
                
            }
            
            inputEvent.putAll(new Map<String,Object>{
                'Hops' => 1,
                'EnqueuedById' => UserInfo.getUserId()
            });
            
            if (inputEvent.get('EntryPointUuid') == null) {
                //#751 'they' are allowed to mess with this, eg for replay
                inputEvent.put('EntryPointUuid', uuidVersionFour());
            }
            
            if (inputEvent.get('EntryPointTimestamp') == null) {
                //#753 processes like Heartbeat are allowed to mess with this}
                inputEvent.put('EntryPointTimestamp', System.now());
            }
            
            this.Events.add(inputEvent);
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
                Id jobId = context.getJobId();
                this.Events[i].put('JobId', jobId);
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
        Broker.impl().persist(messages); //#836
        
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
            AND ApexClass.Name = 'BrokerDispatcher'
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