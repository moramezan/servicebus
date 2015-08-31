/*
 * DO NOT ENQUEUE THIS JOB EVER
 * see http://salesforce.stackexchange.com/a/24448/320
 *
 * This class is WITHOUT SHARING to ensure the process can execute regardless of running user context.
 */
public without sharing class BrokerImplementation extends Broker implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    
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
    
    /**
     * The possible stages of our vertical worker state machine
     * https://github.com/bigassforce/esb/issues/987#issuecomment-131629798
     */
    Enum Stage {
        PersistMark,
        Execute,
        Abort
    }
    
    /**
     * #671 first query locator spends less time in 'Preparing'
     */
    static Boolean IsRestart = false;
    Integer Contexts = IsRestart ? 1000 : 50;
    
    public BrokerImplementation() {
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
     * Some integer below a hard limit of 4000 (min expected rows in FieldPermissions)
     */
    public Database.QueryLocator start(Database.BatchableContext context) {
        //funnily enough "SLOTS" is almost exactly what this is
        return Database.getQueryLocator([
            SELECT Id
            FROM FieldPermissions
            LIMIT :this.Contexts
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
                throw new Broker.PanicException('Unexpected stage: ' + this.NextStage);
                
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
     * a tiny bit of visibility about the problem to the process author / user.
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
            Database.executeBatch(new BrokerDispatcher(), 1);
        } else {
            //TODO be aware schedule is about 5 - 10 seconds slower to start
            Database.executeBatch(new BrokerDispatcher(), 1);
            //System.scheduleBatch(new BrokerDispatcher(), 'Service Bus Broker', 0, 1);
        }
    }
}