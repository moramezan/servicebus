/*
 * DO NOT ENQUEUE THIS JOB EVER
 * see http://salesforce.stackexchange.com/a/24448/320
 *
 * This class is WITHOUT SHARING to ensure the process can execute regardless of running user context.
 */
public without sharing class VerticalBrokerImplementation extends Broker implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    
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
    
    public VerticalBrokerImplementation() {
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
                
                //possible next stage
                this.NextStage = Stage.Abort; //helps 'done' down there
                
                //HANDLE
                if (this.FatalIds != null) this.handleFatalIds(context);
                
                //PERSIST
                this.persist(this.Messages);
                
                //MORE
                if (this.isLastContext(context)) return; //finish happens next
                
                //LOCATE
                this.Messages = this.locateMarkableWork();
                
                //DONE
                if (this.Messages.isEmpty()) return; //uses 'abort' up there
                
                //MARK
                this.mark(this.Messages);
                
                //actual next stage
                this.NextStage = Stage.Execute;
                
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
        IsRestart = true;
        super.run();
    }
    
    public void handleFatalIds(Database.BatchableContext context) {
        //gets "First error: ..." off job
        AsyncApexJob asyncApexJob = [
            SELECT ExtendedStatus
            FROM AsyncApexJob
            WHERE Id = :context.getJobId()
        ];
        
        //write it away on the previous set of messages
        List<Message__c> fatalities = new List<Message__c>();
        for (Id fatalId : this.FatalIds) fatalities.add(new Message__c(
            Id = fatalId,
            ExecuteDuration__c = this.BlameCpuTime, //#987 we fishing to restore this
            Exception__c = 'Fatal Error: Route to blame: ' + this.BlameRoute, //#985
            Cause__c = this.IsFirstFatal ? asyncApexJob.ExtendedStatus : null //#985
        ));
        
        update fatalities;
        this.IsFirstFatal = false;
        this.BlameCpuTime = null;
        this.BlameRoute = null;
        
        //prevent repetition
        this.FatalIds = null;
    }
    
    /**
     * We require TWO contexts to do anything useful, namely MARK
     * and EXECUTE. So when the very last context comes, we skip it.
     * Otherwise any marking would be left without an execute after.
     */
    public Boolean isLastContext(Database.BatchableContext context) {
        if (Test.isRunningTest()) {
            //any context implies last
            return context != null;
        }
        
        AsyncApexJob asyncApexJob = [
            SELECT JobItemsProcessed, TotalJobItems
            FROM AsyncApexJob
            WHERE Id = :context.getJobId()
        ];
        
        //this is our very last context, dont waste it on a mark!
        return asyncApexJob.TotalJobItems == asyncApexJob.jobItemsProcessed + 1;
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
    
    /**
     * Each Broker implementation must provide the smarts of how to restart it.
     * The VerticalBroker executes another Batch Apex job to run itself again.
     */
    override public void runImpl() {
        if (!Job.isRunningUser()) {
            //#847 broker panic, wrong user context
            System.assert(false, 'The configured running user Id=[' + UserInfo.getUserId() + '] is null or invalid');
        }
        
        //TODO this is about 5 - 10 seconds slower to start than executeBatch
        System.scheduleBatch(new VerticalBrokerDispatcher(), 'Enterprise Service Bus Broker', 0, 1);
    }
}