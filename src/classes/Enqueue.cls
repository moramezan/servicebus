global class Enqueue implements Process.Plugin {
    
    public class EnqueueException extends Exception {}
    
    static public Boolean AllowRoute = false; //#999#issuecomment-133751700
    
    //Process.Plugin enqueue = new ServiceBus.Enqueue();
    //enqueue.invoke(event)
    
    /**
     * But this constructor has to be public for Process.Plugin:
     * "System.TypeException: Job does not have a no-arg constructor"
     */
    
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
        plugin.Tag = 'Service Bus';
        plugin.Description = 'Enqueue a Job into the Service Bus';
        
        plugin.InputParameters = new List<Process.PluginDescribeResult.InputParameter>{
            new Process.PluginDescribeResult.InputParameter('RecordId', Process.PluginDescribeResult.ParameterType.ID, false),
            new Process.PluginDescribeResult.InputParameter('ToSequence', Process.PluginDescribeResult.ParameterType.STRING, false),
            new Process.PluginDescribeResult.InputParameter('ToService', Process.PluginDescribeResult.ParameterType.STRING, false)
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
        System.Queueable job = new Job(inputEvent);
        Id jobId = System.enqueueJob(job);
        
        inputEvent.put('JobId', jobId);
        return new Process.PluginResult(inputEvent);
    }
    
    public class QueueImpl implements Job.Queueable {
    
        public List<Map<String,Object>> Events = new List<Map<String,Object>>();
        
        /**
         * Prepares data (represented an input event) for work.
         * A collection of multiple parameterized message descriptions.
         * Each of which must at minimum a Sequence or a Process or a Config or a Route.
         *
         * Prepares data for work at the start of a nominated sequence by wrapping the pointer to the data (an id) in a
         * Message object. This Message instance is saved to the database and the Broker is immeadiately
         * invoked if it is not already running.
         *
         * @docs ApiJobConstructors.html
         * @param sequenceName Name of the sequence the data is destined for.
         * @param dataId    Id of some record that the sequence will operate on.
         *
         * The input event collection should at minimum contain
         *  - an object Id ("Id")
         *  - a sequence ("ToSequence") or a service ("ToService") or a list of possible configs ("ToConfigIds")
         *
         * The input event collection is converted to a Message object. This Message instance is saved
         * to the database and the Broker is immeadiately invoked if it is not already running.
         *
         * @docs ApiJobConstructors.html
         * @param  injectedParameters a parametrised description of the event.
         */
        public void setEvents(List<Map<String,Object>> inputEvents) {
            
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
                'CorrelationUuid',
                'JobId',
                'MessageId',
                'RecordId',
                'ToConfigIds',
                'ToSequence',
                'ToService',
                'Hops',
                AllowRoute ? 'Route' : 'Hops' //TODO confirm if this disallowed
            };
            
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
                    
                    if (key.startsWith(':')) {
                        //failure, reserved for us
                        throw new EnqueueException('Namespace \':\' is not supported. If you are attempting to use a custom event parameter, be sure to prepend the \'c:\' before the parameter name.'); //a la //sObject type 'Messsss' is not supported. If you are attempting to use a custom object, be sure to append the '__c' after the entity name. Please reference your WSDL or the describe call for the appropriate names.
                    }
                    
                    if (!key.contains(':')) {
                        //failure, namespace is required
                        throw new EnqueueException('Namespace \'' + key + '\' is not supported. If you are attempting to use a custom event parameter, be sure to prepend the \'c:\' before the parameter name.'); //a la //sObject type 'Messsss' is not supported. If you are attempting to use a custom object, be sure to append the '__c' after the entity name. Please reference your WSDL or the describe call for the appropriate names.
                    }
                }
                
                //...........................
                
                inputEvent.putAll(new Map<String,Object>{
                    'Hops' => 1,
                    'EnqueuedById' => UserInfo.getUserId()
                });
                
                if (inputEvent.get('CorrelationUuid') == null) {
                    //#751 'they' are allowed to mess with this, eg for replay
                    inputEvent.put('CorrelationUuid', Enqueue.uuidVersionFour());
                }
                
                if (inputEvent.get('EntryPointTimestamp') == null) {
                    //#753 services like Heartbeat are allowed to mess with this}
                    inputEvent.put('EntryPointTimestamp', System.now());
                }
                
                this.Events.add(inputEvent);
            }
        }
        
        /**
         * Was formerly Broker.run() but needs to be global now
         * for the sake of running from Execute Anonymous context.
         * The "runAsUser()" method needs to be able to call this.
         *
         * I think we had 8 global things in Job and 1 in Broker
         * Lets just have 9 global things in Job, and this proxies?
         *
         * We MUST ALWAYS prevent more than 1 running broker worker
         * otherwise they will fight over the work to be marked etc.
         */
        
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
        void restart(Id messageId) {
            //VALIDATE
            Message__c message = (Message__c)ApexDomain.getById(messageId);
            if (message.Exception__c == null) return; //Only messages with an Exception can be restarted
            
            //TODO mark without DML? is it even possible for attempts to increment?
            
            //EXECUTE
            List<Message__c> outputMessages = new MessageSetModel(new List<Message__c>{message}).execute(null);
            
            //PERSIST
            new MessageSetModel(new List<Message__c>{message}).persist(outputMessages);
            
            //#981#issuecomment-131670372 prevent side effects (like batch jobs) escaping
            if (MessageModel.RestartException != null) throw MessageModel.RestartException;
            
            //success, restart the REAL broker to carry on with the outputs
            if (isScheduled()) return;
            if (isRunning()) return;
            Broker.impl().run();
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
            
            //RESTART
            if (context != null && context.getJobId().getSObjectType() == Message__c.SObjectType) {
                this.restart(context.getJobId());
                return;
            }
            
            //#694 puts QueueableContext Job Id on messages. Because when people
            //use System.enqueueJob to enqueue a message into the system, they will
            //never get a Message Id. But at least we have a possibility of using
            //the Queueable AsyncApexJob Id as a correlation later for Capture etc.
            for (Integer i = 0; i < this.Events.size(); i++) {
                Id jobId = context.getJobId();
                this.Events[i].put('JobId', jobId);
            }
            
            //one strategy to reduce heap size during runtime is to
            //remove items from the collection as you iterate over it
            List<Message__c> messages = new List<Message__c>();
            for (Integer i = 0; i < this.Events.size(); i++) {
                messages.add(new Message__c(
                    Event__c = Json.serializePretty(this.Events[i]),
                    Status__c = Application__c.getOrgDefaults().BrokerPaused__c ? 'Paused' : 'Buffered'
                ));
                
                //salesforce does not have iterator.remove() method like java
                //but don't use list.remove(i) that just fucks every odd one!
                this.Events[i] = null;
            }
            
            //#989 optimize already correct running user context
            if (!Test.isRunningTest()) if (isRunAsUser()) this.run(); else this.runAsUser();
            
            //#1149 race condition DML (we just hope the batch is slightly delayed)
            new MessageSetModel(new List<Message__c>()).persist(messages) ; //#836 //#1114 notice empty input list
        }
        
        void run() {
            if (isScheduled()) return;
            if (isRunning()) return;
            Broker.impl().run();
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
        void runAsUser() {
            //#653 don't waste TOOLING API CALL unnecessarily
            if (isScheduled()) return;
            if (isRunning()) return;
            
            //command
            PageReference endpoint = new PageReference(Url.getSalesforceBaseUrl().toExternalForm() + '/services/data/v35.0/tooling/executeAnonymous');
            endpoint.getParameters().put('anonymousBody', 'new ' + Job.class.getName() + '().execute(null);');
            
            //execute anonymous
            HttpRequest request = new HttpRequest();
            request.setTimeout(120000);
            request.setMethod('GET');
            request.setEndpoint(endpoint.getUrl());
            request.setHeader('Authorization', 'Bearer ' + Application__c.getOrgDefaults().RunAsAccessToken__c);
            
            //#653 throw unhandled exception in our namespace
            HttpResponse response = new Http().send(request);
            if (response.getStatusCode() != 200) System.assert(false, response.getBody());
            if (response.getBody().contains('"success":false')) System.assert(false, response.getBody());
        }
        
        //TODO? Job(reflector, recordId)
        //TODO? Job(configIds, recordId)
        
        /**
         * Prepares Blob data for work at the start of a nominated sequence
         * by wrapping the pointer to the data (an id) in a Message object
         * This Persisted Data instance is saved to the database and the Broker is
         * immeadiately invoked threreafter
         *
         * @docs ApiJobConstructors.html
         * @param sequenceName Name of the sequence the data is destined for.
         * @param dataId    Blob representation of the data the sequence will operate on.
         */
        /*public Job(String sequenceName, Blob data) {
            this(sequenceName, Database.insert(new Document(
                Name = String.valueOf(Datetime.now().getTime()),
                Body = data,
                FolderId = UserInfo.getUserId(),
                ContentType = 'text/plain',
                Type = 'txt'
            )).getId());
        }*/
        
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
    
    static public Boolean isRunAsUser() {
        Id userId = UserInfo.getUserId();
        Id runningId = Application__c.getOrgDefaults().RunAsUserId__c;
        return userId == runningId;
    }
    
    static public Boolean isScheduled() {
        List<CronJobDetail> cronJobDetails = [
            SELECT Id
            FROM CronJobDetail
            WHERE Name = 'Service Bus Broker'
            LIMIT 1
        ];
        
        return !cronJobDetails.isEmpty();
    }
    
    static public Boolean isRunning() {
        List<AsyncApexJob> asyncApexJobs = [
            SELECT Id
            FROM AsyncApexJob
            WHERE JobType = 'BatchApex'
            AND ApexClass.Name = 'BrokerBatch'
            AND ApexClass.NamespacePrefix = :Application__c.getOrgDefaults().Prefix__c
            AND Status IN ('Holding', 'Queued', 'Processing', 'Preparing')
            LIMIT 1
        ];
        
        return !asyncApexJobs.isEmpty();
    }
}