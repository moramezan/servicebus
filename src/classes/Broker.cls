/**
 * Very fundamental order:
 *
 * Example sequence:
 * Test#1 [Wiretap]
 * Test#2 [Terminate]
 *
 * [interactive] System.enqueueJob(job)
 * [queueable] execute job
 * [future] call tooling api
 * [tooling] System.scheduleBatch(broker)
 * [schedule] ...wait...
 * [batch.start]
 * [batch.execute] broker.locate() then broker.mark(wiretap)
 * [batch.execute] broker.execute(wiretap)
 * [batch.execute] broker.locate() then broker.persist(wiretap) then broker.mark(terminate)
 * [batch.execute] broker.execute(terminate)
 * [batch.execute] broker.locate() then abort()
 */
/**
 * This class is WITHOUT SHARING to ensure the service can execute regardless of running user context.
 */
abstract public without sharing class Broker {
    
    public class ServiceException extends Exception {}
    
    /**
     * #985 helps avoid misleading errors
     */
    static public Broker Instance;
    public Integer BlameCpuTime;
    public String BlameClass;
    public String BlameRoute;
    public String BlameMessage;
    
    static public Integer MaximumHops = 1000;
    
    static public Broker impl() {
        if (Test.isRunningTest()) {
            //unit test broker
            return (Broker)Type.forName('BrokerTest.SynchronousBroker').newInstance();
        } else {
            //production broker
            return (Broker)Type.forName('Broker.Batch').newInstance();
        }
    }
    
    /**
     * Determines which messages are eligible to be moved into the Started status (by finding Messages
     * with 'Buffered' status).
     *
     * Messages that should be worked on have their status marked as Started in the database before being
     * submitted the query locator. That way, if any given execution fails, those messages will remain in the
     * easily identifiable 'Started' state.
     *
     * CONTEXT A:
     * - Persist (from previous)
     * - Locate (lock for update)
     * - Mark (performs update and puts into stateful, safe from clutches of other jobs)
     *
     * CONTEXT B:
     * - Execute (reads guys off stateful property, does work and performs update)
     *
     * @return collection of soon-to-be-marked-as-Started Messages.
     */
    public List<Message__c> locateMarkableWork() {
        try {
            List<Message__c> specimen = [
                SELECT Id, Route__c, Event__c //TODO lose event? //#1026
                FROM Message__c
                WHERE Status__c = 'Buffered'
                ORDER BY CreatedDate ASC //reattempts will naturally lead
                LIMIT 1
                //TODO: this guy should be FOR UPDATE or risk race condition
            ];
            
            //TODO fucked limits COULD be high if we want performance vs risk
            
            if (specimen.isEmpty()) {
                //no work found, return empty
                return specimen;
            }
            
            ApexClassModel.Summary summary;
            
            try {
                //we have to 'peek' at the service
                ApexClassModel model = new MessageModel(specimen[0]).resolveApexClassModel();
                summary = new ApexClassModel.Summary(model.Reflector);
            } catch (Exception e) {
                //could not resolve, chunks 1
                return specimen;
            }
            
            Integer chunks = summary.Chunks;
            
            //TODO what if this guy returns a list of 0, would cause a panic condition, lets check
            
            return [
                SELECT Id, Route__c, Event__c //TODO lose event? //#1026
                FROM Message__c
                WHERE Status__c = 'Buffered'
                AND Route__c = :specimen[0].Route__c //#1004 Route__c field only ever used here to LOCATE, and for GATE and MONITOR
                LIMIT :chunks
                FOR UPDATE //#695 investigate broker race condition
            ];
            
        } catch (Exception e) {
            throw new ServiceException('Locate panic: ' + e.getMessage() + ' - ' + e.getStackTraceString(), e);
        }
    }
    
    /**
     * Sets many Messages statuses to 'Started' and writes them away.
     * TODO we should be REALLY careful here because it modifies BY REFERENCE
     */
    public void mark(List<Message__c> messages) {
        try {
            for (Message__c message : messages) message.Status__c = 'Started'; //in-database
            List<Database.SaveResult> results = Database.update(messages);
            //#1038 avoid playing with list by reference, hope to avoid memory leak
            
        } catch (Exception e) {
            throw new ServiceException('Mark panic: ' + e.getMessage() + ' - ' + e.getStackTraceString(), e);
        }
    }
    
    /**
     * Resolves and invokes the toStringable Object for one input, updating an in-memory collection of outputs
     *
     * @param  inputMessages pass-by-reference Messages whose status should be Started
     * @param  outputMessages pass-by-reference Messages whose status should be Started
     */
    public void execute(List<Message__c> inputMessages, List<Message__c> outputMessages) {
        Instance = this; //#985
        
        try {
            //empty inputs, empty outputs
            if (inputMessages.isEmpty()) return;
            
            Integer chunkTotal = inputMessages.size();
            Integer chunk = 1;
            for (Message__c inputMessage :  inputMessages) {
                Map<String,Object> inputEvent = (Map<String,Object>)Json.deserializeUntyped(inputMessage.Event__c);
                inputEvent.put('Range', chunkTotal);
                inputEvent.put('Chunk', chunk);
                
                if (inputMessage.Id != null) {
                    //#1026 can't use map and keySet()
                    //because Row with null Id at index: 0
                    Set<Id> siblingIds = new Set<Id>();
                    for (Message__c sibling : inputMessages) siblingIds.add(sibling.Id);
                    inputEvent.put('SiblingIds', siblingIds);
                }
                
                inputMessage.Event__c = Json.serializePretty(inputEvent);
                chunk++;
            }
            
            //OUR FUCKUPS (prepare)
            List<MessageModel> models = new List<MessageModel>();
            for (Message__c inputMessage : inputMessages) {
                MessageModel model = new MessageModel(inputMessage);
                models.add(model);
            }
            
            //THEIR FUCKUPS (callout)
            for (MessageModel model : models) {
                //do invocation
                this.BlameCpuTime = Limits.getCpuTime(); //#985
                model.invokeCallout();
            }
            
            //for isolating chunks from each other
            Savepoint sp = Database.setSavepoint();
            Boolean isolate = false;
            
            //THEIR FUCKUPS (execute)
            for (MessageModel model : models) {
                
                if (isolate) {
                    //consume savepoint only if necessary (side effects)
                    sp = Database.setSavepoint();
                    isolate = false;
                }
                
                //do invocation
                this.BlameCpuTime = Limits.getCpuTime(); //#985
                isolate = model.invokeExecute(outputMessages);
                
                if (model.Message.Exception__c != null && isolate) {
                    //consume rollback only if necessary (error AND side effects)
                    Database.rollback(sp);
                }
            }
            
        } catch (Exception e) {
            throw new ServiceException('Execute panic:' + e.getMessage() + ' - ' + e.getStackTraceString(), e);
        }
    }

    /**
     * #782
     *
     * Maybe we can entertain this :( because this method is now PUBLIC and not GLOBAL.
     *
     * We used to have two arguments for inputMessages and outputMessages. The idea being:
     * that inputMessages were all gonna be written away as "Completed"
     * and outputMessages were all gonna be written away as "Buffered"
     * (ka-chunk)
     *
     * But the checkmarx scanner chokes "Bulkify_Apex_Methods_Using_Collections_In_Methods"
     * which Salesforce have confirmed to be a bug... however it requires a human to do that.
     *
     * To keep the amount of back and forth and delay to a minimum, we can get away with merging
     * the two collections into one, and doing all the status changes in memory:
     * the inputMessages get "Completed" by mark()
     * and outputMessages get "Buffered" by execute()
     *
     *
     */
    static public void persist(List<Message__c> inputAndOutputMessages) {
        try {
            
            /**
             * In #658 we hoped to expose Sequence API in Broker.persist() since
             * that is the central entry point for any enqueued AND output messages.
             *
             * Since #677 there is history around which operations belong where:
             * - Service does bare metal input cycling, output aggregation,
             * - ApexClassModel can enforce validation at the event level,
             * - MessageModel takes grabs exceptions for the database,
             * - Broker deals with executing message collections,
             *
             * Since we want any "resolve" to happen in ONE place, this appears to
             * be the only place left to put it. Here in the persist works OK because
             * messages "without ids" are NEW ONES. Existing ones won't get re incremented.
             */
            for (Message__c message : inputAndOutputMessages) if (message.Id == null) {
                Map<String,Object> event = (Map<String,Object>)Json.deserializeUntyped(message.Event__c);
                
                //increments route position
                if (event.containsKey('Route')) {
                    String route = (String)event.get('Route');
                    String version = route.substringBefore('#');
                    String sequence = route.substringAfter('#').substringBefore('#');
                    String position = route.substringAfterLast('#');
                    if (route.contains('#')) event.put('Route', (Integer.valueOf(version)) + '#' + sequence + '#' + (Integer.valueOf(position) + 1));
                }
                
                message.Event__c = Json.serialize(event);
            }
            
            //transact both inputs and outputs in one fell swoop
            MessageSetModel.Inhibit = false;
            Database.upsert(inputAndOutputMessages);
            MessageSetModel.Inhibit = true;
            
        } catch (Exception e) {
            throw new ServiceException('Persist panic: ' + e.getMessage() + ' - ' + e.getStackTraceString(), e);
        }
    }
    
    /**
     * Formerly restartIfWorkPending
     * The VerticalBroker executes another Batch Apex job to run itself again.
     *
     * Per #929 we can use System.scheduleBatch to NAME THE JOB which lets us
     * lean on the platform to prevent races. Salesforce will block second job!
     *
     * If you try and schedule TWO jobs in ONE execution context:
     * System.AsyncException: The Apex job named 'test' is already scheduled for execution.
     *
     * Or if you scheduled ONE job in each of TWO execution contexts:
     * System.UnexpectedException: common.exception.SqlDupValOnIndexException: ORA-00001: unique constraint (CORE.AKCRON_JOB_DETAIL) violated
     *
     * We see one of the seven dwarves appearing too:
     * ORA-06512: at "HAPPY.UDDDMLCRONJOBDETAIL", line 32
     * ORA-06512: at "HAPPY.CCRONJOBDETAIL", line 95
     * ORA-06512: at line 1
     * {call cCronJobDetail.insert_detail(?,?,?,?,?,?,?,?,?,?,?)}
     * {call cCronJobDetail.insert_detail(?,?,?,?,?,?,?,?,?,?,?)}
     */
    public void run() {
        if (BrokerSetting__c.getOrgDefaults().Inhibit__c) {
            //INHIBIT
            System.assert(false, 'Inhibit');
        }
        
        if ([SELECT Id FROM Message__c WHERE Status__c = 'Buffered' LIMIT 1].isEmpty()) {
            //nothing to do
            return;
        }
        
        this.runImpl();
        
    }
    
    abstract public void runImpl();
    
    static public Boolean isAllowedSessionId(String reflectorName, Id orgId) {
        if (!Test.isRunningTest() && Broker.class.getName() == 'Broker') return true; //unmanaged deployment ok
        
        Set<String> sessionIdOrgs = new Set<String>{
            '00Dj0000000I44v', // dev org - matt
            '00Dj0000001oeWV', // dev org - neil
            '00Dj0000001q22l', // dev org - harsha
            '00Do0000000dQSB', // dev org - natani
            '00Dj0000001uJgw'  // dev org - tom
        };
        Set<String> sessionIdNamespaces = new Set<String>{
            'servicebus',
            'servicebus_batchpdf',
            'servicebus_tooling',
            'servicebus_metadata'
        };
        String namespacePrefix  = reflectorName.subStringBefore('.');
        String orgId15 = String.valueOf(orgId).left(15);
 
        return sessionIdOrgs.contains(orgId15) || sessionIdNamespaces.contains(namespacePrefix);
    }
    
    /**
     * #671 first query locator spends less time in 'Preparing'
     */
    static Boolean IsRestart = false;
    
    /**
     * The possible stages of our vertical worker state machine
     * https://github.com/bigassforce/servicebus/issues/987#issuecomment-131629798
     */
    Enum Stage {
        PersistMark,
        Execute,
        Abort
    }
    
    /*
     * DO NOT ENQUEUE THIS JOB EVER
     * see http://salesforce.stackexchange.com/a/24448/320
     *
     * This class is WITHOUT SHARING to ensure the service can execute regardless of running user context.
     */
    public without sharing class Batch extends Broker implements BrokerBatch.Batchable {
        
        /**
         * #985 helps avoid misleading errors
         */
        @TestVisible Boolean IsFirstFatal = true;
        
        /**
         * Used for communicating which messages had fatal
         * errors across contexts: execute-to-persist
         */
        @TestVisible Set<Id> FatalIds;
        
        /**
         * Used for communicating across contexts:
         * mark-to-execute and also execute-to-persist
         */
        @TestVisible List<Message__c> Messages = new List<Message__c>();
        
        public Batch() {
            if (!Job.isRunningUser()) {
                //#847 broker panic, wrong user context
                System.assert(false, 'The configured running user Id=[' + UserInfo.getUserId() + '] is null or invalid');
            }
        }
    
        /**
         * The first execution context will always be a mark
         */
        @TestVisible Stage NextStage = Stage.PersistMark;
        
        /**
         * Some integer below a hard limit of 1000 (number of rows in Slot__c)
         */
        public Database.QueryLocator start(Database.BatchableContext context) {
            //funnily enough "SLOTS" is almost exactly what this is
            return Database.getQueryLocator([
                SELECT Id, Name
                FROM Slot__c
                ORDER BY Name ASC
                LIMIT :IsRestart ? 1000 : 50
            ]);
        }
        
        /**
         * Each execution context needs to know what to do. Rather than inferring
         * from the former "markable" or "executable" or "persistable" variables,
         * we can be more like a state machine that instructs the next STAGE.
         */
        public void execute(Database.BatchableContext context, List<SObject> scopes) {
            try {
                if (this.NextStage == Stage.PersistMark) {
                    
                    //actual next stage
                    this.NextStage = Stage.Execute;
                    
                    //HANDLE
                    if (this.FatalIds != null) this.handleFatalIds(context);
                    
                    //PERSIST
                    Broker.persist(this.Messages);
                    
                    //LOCATE
                    this.Messages = this.locateMarkableWork();
                    
                    //MARK
                    this.mark(this.Messages);
                    
                    //DONE
                    if (this.Messages.isEmpty()) this.NextStage = Stage.Abort;
                    
                } else if (this.NextStage == Stage.Execute) {
                    
                    //actual next stage
                    this.NextStage = Stage.PersistMark;
                    
                    //all fatalities
                    this.FatalIds = new Map<Id,SObject>(this.Messages).keySet();
                    
                    //EXECUTE
                    List<Message__c> outputMessages = new List<Message__c>();
                    List<Message__c> inputMessages = this.Messages;
                    this.Messages = new List<Message__c>();
                    this.execute(inputMessages, outputMessages);
                    this.Messages.addAll(inputMessages);
                    this.Messages.addAll(outputMessages);
                    
                    //no fatalities
                    this.FatalIds = null;
                    
                } else if (this.NextStage == Stage.Abort) {
                    
                    //ABORT
                    System.abortJob(context.getJobId());
                    
                } else {
                    
                    //PANIC
                    throw new Broker.ServiceException('Broker Panic. Unexpected stage: ' + this.NextStage);
                    
                }
            } catch (Exception e) {
                
                /**
                 * If we encounter any kind of unexpected exception (catchable or otherwise)
                 * inside this batch job, we risk that the QueryLocator will loop forever. When
                 * that condition is detected, we leave First Error THEN bail on next cycle.
                 */
                this.NextStage = Stage.Abort;
                throw e;
                
            }
        }
        
        /**
         * HANDLE is not needed on the last guy here, so
         * long as number of contexts is an even number?
         */
        public void finish(Database.BatchableContext context) {
            
            //#991 HANDLE
            if (this.FatalIds != null) this.handleFatalIds(context);
            
            //#991 PERSIST
            Broker.persist(this.Messages);
            
            IsRestart = true;
            super.run();
        }
        
        /**
         * The new reason we can't persist such errors in the execute() method is
         * because they are uncatchable exceptions like System.assert() or Limits.
         *
         * While we can't get the stack trace of these exceptions, we can do ever so
         * slightly better and pull the detail off the job's ExtendedStatus to give
         * a tiny bit of visibility about the problem to the service author / user.
         *
         * There is always ONE place to go for the information: Message__c.Exception__c
         */
        public void handleFatalIds(Database.BatchableContext context) {
            //prevent repetition
            List<Id> messageIds = new List<Id>(this.FatalIds);
            this.FatalIds = null;
            
            //gets "First error: ..." off job
            AsyncApexJob asyncApexJob = [
                SELECT ExtendedStatus
                FROM AsyncApexJob
                WHERE Id = :context.getJobId()
            ];
            
            String message = this.IsFirstFatal //#985
                ? ('First error: ' + asyncApexJob.ExtendedStatus).substringAfterLast('First error: ')
                : 'Fatal error: restart message'
            ;
            
            String cause = '' //#985
                + 'Class: ' + this.BlameClass
                + '\nRoute: ' + this.BlameRoute
                + '\nMessage: ' + this.BlameMessage
            ;
            
            //write it away on the previous set of messages
            List<Message__c> fatalities = new List<Message__c>();
            for (Id messageId : messageIds) fatalities.add(new Message__c(
                Id = messageId,
                ExecuteDuration__c = this.BlameCpuTime, //#987 we fishing to restore this
                Exception__c = message, //#985
                Cause__c = cause //#985
            ));
            
            update fatalities;
            this.IsFirstFatal = false;
            this.BlameCpuTime = null;
            this.BlameClass = null;
            this.BlameRoute = null;
            this.BlameMessage = null;
        }
        
        /**
         * Each Broker implementation must provide the smarts of how to restart it.
         * The VerticalBroker executes another Batch Apex job to run itself again.
         */
        override public void runImpl() {
            if (!Job.isRunningUser()) {
                //#847 broker panic, wrong user context
                System.assert(false, 'The configured running user Id=[' + UserInfo.getUserId() + '] is null or invalid');
            }
            
            if (IsRestart) {
                //TODO consider if finish is exclusive enough to do this
                Database.executeBatch(new BrokerBatch(), 1);
            } else {
                //TODO be aware schedule is about 5 - 10 seconds slower to start
                Database.executeBatch(new BrokerBatch(), 1);
                //System.scheduleBatch(new BrokerBatch(), 'Service Bus Broker', 0, 1);
            }
        }
    }
}