global class Enqueue implements Process.Plugin {
    
    public class EnqueueException extends Exception {}

    static public Boolean AllowRoute = false;

    /**
     * <?xml version=1.0 encoding=UTF-8?>
     * <env:Envelope xmlns:env=http://schemas.xmlsoap.org/soap/envelope/ xmlns:xsi=http://www.w3.org/2001/XMLSchema-instance xmlns:xsd=http://www.w3.org/2001/XMLSchema>
     *     <env:Header>
     *         <SessionHeader xmlns=urn:tooling.soap.sforce.com>
     *             <sessionId>00D24000000rJpZ_____AQ4AQGpDqiI3VYXwWf4DRnokaGOrD0HjPa1XTy.lGX1SnKvZ_7ikRiDIOX_xHHuoS2JY_5XXPem.iymvbf6Zxc4yj6cwQmxE</sessionId>
     *         </SessionHeader>
     *     </env:Header>
     *     <env:Body>
     *         <executeAnonymous xmlns=urn:tooling.soap.sforce.com>
     *             <String>System.assert(false, 12345);</String>
     *         </executeAnonymous>
     *     </env:Body>
     * </env:Envelope>
     *
     * <?xml version=1.0 encoding=UTF-8?>
     * <soapenv:Envelope xmlns:soapenv=http://schemas.xmlsoap.org/soap/envelope/ xmlns=urn:tooling.soap.sforce.com xmlns:xsi=http://www.w3.org/2001/XMLSchema-instance>
     *     <soapenv:Body>
     *         <executeAnonymousResponse>
     *             <result>
     *                 <column>1</column>
     *                 <compileProblem xsi:nil=true/>
     *                 <compiled>true</compiled>
     *                 <exceptionMessage>System.AssertException: Assertion Failed: 12345</exceptionMessage>
     *                 <exceptionStackTrace>AnonymousBlock: line 1, column 1</exceptionStackTrace>
     *                 <line>1</line>
     *                 <success>false</success>
     *             </result>
     *         </executeAnonymousResponse>
     *     </soapenv:Body>
     * </soapenv:Envelope>
     */
    static public void integrationCommand(Map<String,Object> parameters) {
        
        if (Test.isRunningTest() || Application__c.getOrgDefaults().RunAsUserId__c == UserInfo.getUserId()) {
            //already integration user
            new Enqueue().invoke(new Process.PluginRequest(parameters));
            return;
        }
        
        //prepare session
        Application__c setting = Application__c.getOrgDefaults();
        setting.RunAsAccessToken__c = ConfigureController.refreshAccessToken();
        
        //prepare command
        String command = ''
            + 'new ' + Enqueue.class.getName() + '().invoke(new Process.PluginRequest('
            + '    (Map<String,Object>)Json.deserializeUntyped(\'' + Json.serialize(parameters) + '\')'
            + '));'
        ;
        
        //soap namespace
        Dom.Document dom = new Dom.Document();
        String env = 'http://schemas.xmlsoap.org/soap/envelope/';
        String xsd = 'http://www.w3.org/2001/XMLSchema';
        String xsi = 'http://www.w3.org/2001/XMLSchema-instance';
        String xmlns = 'urn:tooling.soap.sforce.com';
        
        //soap envelope
        Dom.XmlNode envelope = dom.createRootElement('Envelope', env, 'env');
        envelope.setNamespace('xsi', xsi);
        envelope.setNamespace('xsd', xsd);
        
        //soap header
        Dom.XmlNode header = envelope.addChildElement('Header', env, 'env');
        Dom.XmlNode sessionHeader = header.addChildElement('SessionHeader', xmlns, '');
        Dom.XmlNode sessionId = sessionHeader.addChildElement('sessionId', null, null);
        sessionId.addTextNode(setting.RunAsAccessToken__c);
        
        //soap body
        Dom.XmlNode body = envelope.addChildElement('Body', env, 'env');
        Dom.XmlNode executeAnonymous = body.addChildElement('executeAnonymous', xmlns, '');
        Dom.XmlNode strinq = executeAnonymous.addChildElement('String', null, null);
        strinq.addTextNode(command);
        
        //post request
        HttpRequest request = new HttpRequest();
        request.setTimeout(120000);
        request.setMethod('POST');
        request.setHeader('SOAPAction', '""');
        request.setHeader('Content-Type', 'text/xml');
        request.setEndpoint(Url.getSalesforceBaseUrl().toExternalForm().replace('http:', 'https:') + '/services/Soap/T/36.0');
        request.setBody(dom.toXmlString());
        HttpResponse response = new Http().send(request);
        
        //#653 throw exception in our namespace
        if (response.getStatusCode() != 200) throw new EnqueueException(response.getBody());
        if (response.getBody().contains('<success>false</success>')) throw new EnqueueException(response.getBody());
    }
    
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
        plugin.Name = 'Enqueue Services Job';
        plugin.Tag = 'Services';
        plugin.Description = 'Enqueue a Job into the Services';
        
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
     * Per #1268
     * We use the singular name "event" because that is described
     * on the generated REST endpoint and becomes codified JSON.
     * eg the raw POST data is {"inputs":[{"event":"{}"}]}
     */
    @InvocableMethod(label='Services Enqueue') static global List<Id> invoke(List<String> event) {
        List<Id> jobIds = new List<Id>();
        
        for (String data : event) {
            Map<String,Object> inputEvent = (Map<String,Object>)Json.deserializeUntyped(data);
            Id jobId = Enqueue.invoke(inputEvent);
            jobIds.add(jobId);
        }
        
        return jobIds;
    }
    
    /**
     * Per #702 this enables developers to Enqueue into Services without a compile-time
     * dependency, by leveraging the Process.Plugin system interface.
     *
     * @docs ApiJobClass.html
     * Secondarily it also DOUBLES as a REAL Process.Plugin that people can use
     * in Visual Flow to get stuff into Services. (Though they would create a dependency.)
     */
    global Process.PluginResult invoke(Process.PluginRequest request) {
        
        Map<String,Object> inputEvent = request.InputParameters;
        
        //INTEGRATION COMMANDS
        if (inputEvent.get('ToService') == 'Services.ExecuteJobId') {
            //execute by message id
            Id jobId = (Id)inputEvent.get('RecordId');
            MessageSetModel model = MessageSetModel.fromJobId(jobId);
            model.persist(model.execute(null));
            return null;
        }
        
        if (inputEvent.get('ToService') == 'Services.RestartMessageId') {
            //restart by message id
            Id messageId = (Id)inputEvent.get('RecordId');
            MessageModel model = MessageModel.fromId(messageId);
            model.restart();
            return null;
        }
        
        if (inputEvent.get('ToService') == 'Services.RunBrokerBatch') {
            //run batch broker
            if (Test.isRunningTest()) System.assert(false, 'TODO wat');
            Broker.impl().run();
            return null;
        }
        
        //DYNAMIC ENQUEUE
        Id jobId = Enqueue.invoke(inputEvent);
        Map<String,Object> result = inputEvent.clone();
        result.put('JobId', jobId);
        return new Process.PluginResult(result);
    }
    
    static global Id invoke(Map<String,Object> event) {
        return invoke(new List<Map<String,Object>>{event});
    }
    
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
    static global Id invoke(List<Map<String,Object>> events) {
        
        List<Message__c> messages = new List<Message__c>();
        List<Map<String,Object>> inputEvents = (List<Map<String,Object>>)events;
        
        if (inputEvents == null) {
            //failure, bad input collection
            throw new EnqueueException('Enqueued events cannot be null');
        }
        
        if (inputEvents.isEmpty()) {
            //nothing to do
            throw new EnqueueException('No events to enqueue.');
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
            'Immediate',
            'EnqueuedById',
            'EntryPointTimestamp',
            'CorrelationUuid',
            'JobId',
            'RecordId',
            'ToConfigIds',
            'ToSequence',
            'ToService',
            'Hops'
        };

        if (AllowRoute) legalKeys.add('Route');

        Datetime timestamp = System.now();
        Object route = inputEvents[0].get('Route');
        Object immediate = inputEvents[0].get('Immediate');
        Object toService = inputEvents[0].get('ToService');
        Object toSequence = inputEvents[0].get('ToSequence');
        Object toConfigIds = inputEvents[0].get('ToConfigIds');

        for (Integer i = 0; i < inputEvents.size(); i++) {
            
            Map<String,Object> inputEvent = inputEvents[i];
            
            if (inputEvent == null) {
                //failure, one bad input event
                throw new EnqueueException('Enqueued event cannot be null'); //a la System.NullPointerException: Argument cannot be null
            }

            if (immediate != null && inputEvent.get('Immediate') != immediate) {
                //failure, mixed immediacy
                throw new EnqueueException('Enqueueing groups of immediate and non-immediate events is not permitted. List the Immediate events together and enqueue those in a separate job.');
            }

            if (toService != null && toSequence != null) {
                //failure, mixed one-shot / sequence routing
                throw new EnqueueException('Enqueueing groups of events to a mix of sequences and services is not permitted. List the ToSequence events together and enqueue those in a separate job.');
            }
            
            if (toService != null && toConfigIds != null) {
                //failure, mixed one-shot / config routing
                throw new EnqueueException('Enqueueing groups of events to a mix of configs and services is not permitted. List the ToConfigIds events together and enqueue those in a separate job.');
            }
            
            if (toService != null && inputEvent.get('ToService') != toService) {
                //failure, mixed one-shots with different services
                throw new EnqueueException('Enqueueing groups of events to different services is not permitted. List the events together by service and enqueue the different services in separate jobs.');
            }
            
            if (toService == null && toSequence == null && toConfigIds == null && route == null) {
                //failure, completely unroutable
                throw new EnqueueException('Enqueueing events without a route is not permitted. Populate one of the event parameters: ToService, ToSequence, ToConfigIds.');
            }
            
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
            
            inputEvent.putAll(new Map<String,Object>{
                'Hops' => 1,
                'EnqueuedById' => UserInfo.getUserId()
            });
            
            if (inputEvent.get('CorrelationUuid') == null) {
                //#751 'they' are allowed to mess with this, eg for replay
                inputEvent.put('CorrelationUuid', uuidVersionFour());
            }
            
            if (inputEvent.get('EntryPointTimestamp') == null) {
                //#753 services like Heartbeat are allowed to mess with this}
                inputEvent.put('EntryPointTimestamp', timestamp);
            }
        }
        
        //#1220 COMMON ENQUEUE
        Job job = new Job();

        //#1242 need jobid even when paused
        Savepoint savepoint = Database.setSavepoint();

        Id jobId = System.enqueueJob(job);

        //#1242 consistently consume DML whether or not paused or IMMEDIATE
        if (Application__c.getOrgDefaults().BrokerIsPaused__c || immediate == false) Database.rollback(savepoint); else savepoint = Database.setSavepoint();

        if (Test.isRunningTest()) jobId = '707000123456789';
        
        //convert events to messages
        for (Integer i = 0; i < inputEvents.size(); i++) {
            
            //sequence fields
            String slot = null;
            Decimal numberOfAttempts = 0;
            String status = 'Buffered';
            
            //one-shot fields
            if (toService != null) {
                slot = '0000';
                numberOfAttempts = 1;
                status = 'Started';
            }

            //immediate fields
            if (immediate == false) {
                slot = null;
                numberOfAttempts = 0;
                status = 'Buffered';
            }

            //paused fields
            if (Application__c.getOrgDefaults().BrokerIsPaused__c) {
                slot = null;
                numberOfAttempts = 0;
                status = 'Paused';
            }

            //populate job id inside event
            inputEvents[i].put('JobId', jobId);
            
            messages.add(new Message__c(
                Slot__c = slot,
                JobId__c = jobId,
                Status__c = status,
                NumberOfAttempts__c = numberOfAttempts,
                Event__c = Json.serializePretty(inputEvents[i]),
                OwnerId = Application__c.getOrgDefaults().RunAsUserId__c
            ));
            
            //one strategy to reduce heap size during runtime is to
            //remove items from the collection as you iterate over it
            inputEvents[i] = null; //avoid list.remove - it corrupts
        }
        
        //#1220 COMMON PERSIST
        new MessageSetModel(new List<Message__c>()).persist(messages);
        
        return jobId;
    }
    
    public class QueueImpl implements Job.Queueable {
        
        public void execute(QueueableContext context) {
            
            Id jobId = context.getJobId();
            if (Test.isRunningTest()) jobId = '707000123456789';
            MessageSetModel model = MessageSetModel.fromJobId(jobId);
            
            //#1220 HANDLE ONE SHOT
            if (!model.Messages[0].Route__c.contains('#')) {
                
                //integration user execute/persist
                integrationCommand(new Map<String,Object>{'ToService' => 'Services.ExecuteJobId', 'RecordId' => jobId});
                return;
                
            }
            
            //already running
            if (Broker.isRunning()) return;
            
            //about to run
            if (Broker.isScheduled()) return;
            
            //tests need to run own broker
            if (Test.isRunningTest()) return;
            
            //per #1215 only start if not paused
            if (Application__c.getOrgDefaults().BrokerIsPaused__c) return;
            
            //#1220 HANDLE SEQUENCE
            if (model.Messages[0].Route__c.contains('#')) {
                
                //integration user broker start #989
                integrationCommand(new Map<String,Object>{'ToService' => 'Services.RunBrokerBatch'});
                return;
                
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
         * Usually handled within a second or so.
         * NOT TO BE CONFUSED WITH BROKER.EXECUTE
         *
         * But since we aren't actually doing anything with the QueueableContext
         * this works without startTest/stopTest: new Job(inputEvent).execute(null)
         *
         * #816 https://cloud.githubusercontent.com/assets/1878631/6813469/15c4d956-d27e-11e4-9d3d-e7026e95eade.jpg
         */
        
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
    
}