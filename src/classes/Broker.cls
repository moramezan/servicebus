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
    
    static public Integer MaximumHops = 1000;
        
    static public Broker impl() {
        if (Test.isRunningTest()) {
            //unit test broker
            return (Broker)Type.forName('BrokerTest.SynchronousBroker').newInstance();
        } else {
            //production broker
            return (Broker)Type.forName('Broker.BatchImpl').newInstance();
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
    abstract public void run();
    
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
    @TestVisible static Boolean IsRestart = false;
    
    /*
     * DO NOT ENQUEUE THIS JOB EVER
     * see http://salesforce.stackexchange.com/a/24448/320
     *
     * This class is WITHOUT SHARING to ensure the service can execute regardless of running user context.
     */
    public without sharing class BatchImpl extends Broker implements BrokerBatch.Batchable {
        
        /**
         * #985 helps avoid misleading errors
         */
        public Id FatalMessageId;
        public Long FatalCpuTime = Datetime.now().getTime();
        
        /**
         * Used for communicating across contexts:
         * mark-to-execute and also execute-to-persist
         */
        @TestVisible Exception Panic;
        @TestVisible Integer Contexts = IsRestart ? 999 : 99;
        @TestVisible List<Message__c> InputMessages = new List<Message__c>();
        @TestVisible List<Message__c> OutputMessages = new List<Message__c>();
        
        /**
         * Some integer below a hard limit of 1000 (number of rows in Slot__c)
         *
         * The ONLY reason we use slots here is to get a cursor on a safe object?
         * We don't use slots as a marker for odd-even?
         * We don't use slots as a pointer for previous exceptions?
         */
        public Database.QueryLocator start(Database.BatchableContext context) {
            
            if (Application__c.getOrgDefaults().BrokerInhibit__c) {
                //INHIBIT
                System.assert(false, 'Inhibit');
            }
            
            String slot = '0000';
            
            try {
                
                //MARK (or abort if nothing located)
                this.InputMessages = MessageSetModel.locateMarkableWork();
                new MessageSetModel(this.InputMessages).mark(slot);
                if (this.InputMessages.isEmpty()) System.abortJob(context.getJobId());
            
            } catch (Exception e) {
                
                e.setMessage('START PANIC' + '[' + e.getLineNumber() + ']' + '|' + e.getTypeName() + ': ' + e.getMessage() + '\n' + e.getStackTraceString());
                throw e;
                
            }
            
            //funnily enough "SLOTS" is almost exactly what this is
            return Database.getQueryLocator([
                SELECT Id, Name
                FROM Slot__c
                ORDER BY Name ASC
                LIMIT :this.Contexts
            ]);
        }
        
        /**
         * Each execution context needs to know what to do. Rather than inferring
         * from the former "markable" or "executable" or "persistable" variables,
         * we can be more like a state machine that instructs the next STAGE.
         */
        public void execute(Database.BatchableContext context, List<Slot__c> slots) {
            
            if (this.Panic != null) {
                //stateful property survives
                System.abortJob(context.getJobId());
                return;
            }
            
            try {
                
                //0001, 0002, 0003...
                String slot = slots[0].Name;
                Boolean isOdd = Math.mod(Integer.valueOf(slot), 2) == 1;
                
                if (isOdd) {
                    
                    //EXECUTE
                    this.OutputMessages = null; //for fatal error detection
                    this.OutputMessages = new MessageSetModel(this.InputMessages).execute(this);
                    
                } else {
                    
                    //PERSIST (or handle fatal errors)
                    if (this.OutputMessages != null) new MessageSetModel(this.InputMessages).persist(this.OutputMessages);
                    if (this.OutputMessages == null) this.handleFatalExceptions(this.InputMessages, context);
                    
                    //MARK (or abort if nothing located)
                    this.InputMessages = MessageSetModel.locateMarkableWork();
                    new MessageSetModel(this.InputMessages).mark(slot);
                    if (this.InputMessages.isEmpty()) System.abortJob(context.getJobId());
                    
                }
                
            } catch (Exception e) {
                
                e.setMessage('EXECUTE PANIC' + '[' + e.getLineNumber() + ']' + '|' + e.getTypeName() + ': ' + e.getMessage() + '\n' + e.getStackTraceString());
                this.Panic = e;
                throw e;
                
            }
            
        }
        
        /**
         * HANDLE is not needed on the last guy here, so
         * long as number of contexts is an odd number?
         */
        public void finish(Database.BatchableContext context) {
            
            try {
                
                //PERSIST (or handle fatal errors)
                if (this.OutputMessages != null) new MessageSetModel(this.InputMessages).persist(this.OutputMessages);
                if (this.OutputMessages == null) this.handleFatalExceptions(this.InputMessages, context);
                
                //MORE
                IsRestart = true;
                if (![SELECT Id FROM Message__c WHERE Status__c = 'Buffered' LIMIT 1].isEmpty()) this.run();
                
            } catch (Exception e) {
                
                e.setMessage('FINISH PANIC' + '[' + e.getLineNumber() + ']' + '|' + e.getTypeName() + ': ' + e.getMessage() + '\n' + e.getStackTraceString());
                throw e;
                
            }
        }
        
        /**
         * Each Broker implementation must provide the smarts of how to restart it.
         * The VerticalBroker executes another Batch Apex job to run itself again.
         */
        override public void run() {
            
            if (!Enqueue.isRunAsUser()) {
                //#847 broker panic, wrong user context
                System.assert(false, 'The configured running user Id=[' + UserInfo.getUserId() + '] is null or invalid');
            }
            
            Database.executeBatch(new BrokerBatch(), 1);
            //TODO be aware schedule is about 5 - 10 seconds slower to start
            //System.scheduleBatch(new BrokerBatch(), 'Service Bus Broker', 0, 1);
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
        public void handleFatalExceptions(List<Message__c> inputMessages, Database.BatchableContext context) {
            
            //#1123 ensures we don't write erroneous exceptions to irrelevant messages
            Set<Id> inputMessageIds = new Map<Id,SObject>(inputMessages).keySet();
            
            List<Message__c> fatalities = [
                SELECT Id, Route__c
                FROM Message__c
                WHERE Status__c = 'Started'
                AND Slot__c != null
                AND Id IN :inputMessageIds
            ];
            
            //nothing to do (should never happen!)
            if (fatalities.isEmpty()) throw new ServiceException('Could not find fatalities!');
            
            //get "First error: ..." off job
            AsyncApexJob asyncApexJob = (AsyncApexJob)ApexDomain.getById(context.getJobId());
            
            //get causing class name
            String cause = 'Class.';
            Step__c step = Step__c.getValues(fatalities[0].Route__c);
            if (step == null) cause += fatalities[0].Route__c; else cause += step.ApexClassName__c;
            
            //#985 first fatal error (use extended status)
            String extendedStatus = asyncApexJob.ExtendedStatus;
            String message = ('First error: ' + extendedStatus).substringAfterLast('First error: ');
            
            //subsequent fatal error (no idea what exception is)
            if (asyncApexJob.NumberOfErrors != 1) message = 'Fatal error: Restart this message for details.';
            
            for (Message__c fatality : fatalities) {
                
                //chunked collateral damage (exception is misleading)
                if (fatality.Id != this.FatalMessageId) message = 'Chunk error: Message ' + this.FatalMessageId + ' threw uncatchable exception.';
                
                fatality.ExecuteDuration__c = System.now().getTime() - this.FatalCpuTime; //#985 near enough
                fatality.Exception__c = message.abbreviate(SObjectType.Message__c.Fields.Exception__c.Length);
                fatality.Cause__c = cause;
                fatality.Slot__c = null;
            }
            
            update fatalities;
        }
        
    }
}