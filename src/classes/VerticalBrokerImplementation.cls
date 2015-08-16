/*
 * DO NOT ENQUEUE THIS JOB EVER
 * see http://salesforce.stackexchange.com/a/24448/320
 *
 * This class is WITHOUT SHARING to ensure the process can execute regardless of running user context.
 */
public without sharing class VerticalBrokerImplementation extends Broker implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    
    @TestVisible Set<Id> FatalIds = new Set<Id>();
    @TestVisible List<Message__c> Messages = new List<Message__c>();
    @TestVisible Boolean IsAborted = false;
    
    public Stage NextStage = Stage.PersistAndLocateAndMark;
    
    Enum Stage {
        PersistAndLocateAndMark,
        Execute,
        Handle,
        Abort
    }
    
    public VerticalBrokerImplementation() {
        if (UserInfo.getUserId() != OAuthSetting__c.getOrgDefaults().RunningUserId__c) {
            //#847 broker panic, wrong user context
            System.assert(false, 'The configured running user Id=[' + UserInfo.getUserId() + '] is null or invalid');
        }
    }

    /**
     * If we encounter any kind of unexpected exception (catchable or otherwise)
     * inside this batch job, we risk that the QueryLocator will loop forever. This
     * flag can be set when that condition is detected.
     */
    @TestVisible private Boolean IsPanic = false;
    
    /**
     * #671 first query locator spends less time in 'Preparing'
     */
    @TestVisible private Integer Contexts = System.isBatch() ? 1000 : 50;
    
    /**
     * Some integer below a hard limit of 4000 (min expected rows in FieldPermissions)
     */
    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([SELECT Id FROM FieldPermissions LIMIT :this.Contexts]);
    }
    
    /**
     * +------------------+---------------------+------------------+
     * | Has work to MARK | Has work to EXECUTE | Action to take   |
     * +------------------+---------------------+------------------+
     * | 0                | 0                   | Done, abort job! |
     * +------------------+---------------------+------------------+
     * | 0                | 1                   | Broker.execute   | (would likely abort next)
     * +------------------+---------------------+------------------+
     * | 1                | 0                   | Broker.mark      | (would likely execute next)
     * +------------------+---------------------+------------------+
     * | 1                | 1                   | Broker.execute   | (would likely mark next)
     * +------------------+---------------------+------------------+
     */
    public void execute(Database.BatchableContext context, List<SObject> scopes) {
        
        if (this.IsPanic) {
            System.abortJob(context.getJobId());
            return;
        }
        
        this.Contexts--;
        
        try {
            
            if (this.NextStage == Stage.PersistAndLocateAndMark) {
                
                //PERSIST
                this.persist(this.Messages);
                
                //MORE
                if (this.Contexts <= 1) {
                    //don't mark if we can't execute
                    return;
                }
                
                //LOCATE
                this.Messages = this.locateMarkableWork();
                
                //ABORT
                if (this.Messages.isEmpty()) {
                    //don't execute if nothing to do
                    if (Test.isRunningTest()) this.IsAborted = true;
                    else System.abortJob(context.getJobId());
                    return;
                }
                
                //MARK
                this.mark(this.Messages);
                
                //next
                this.NextStage = Stage.Execute;
                
            } else if (this.NextStage == Stage.Execute) {
                
                //next
                this.NextStage = Stage.Handle;
                this.FatalIds = new Map<Id,SObject>(this.Messages).keySet();
                
                //EXECUTE
                List<Message__c> outputMessages = new List<Message__c>();
                List<Message__c> inputMessages = this.Messages;
                this.Messages = new List<Message__c>();
                this.execute(inputMessages, outputMessages);
                this.Messages.addAll(inputMessages);
                this.Messages.addAll(outputMessages);
                
                //next
                this.FatalIds = new Set<Id>();
                this.NextStage = Stage.PersistAndLocateAndMark;
                
            } else if (this.NextStage == Stage.Handle) {
                
                //HANDLE FATAL EXCEPTIONS
                AsyncApexJob asyncApexJob = [SELECT ExtendedStatus FROM AsyncApexJob WHERE Id = :context.getJobId()];
                
                List<Message__c> fatalities = new List<Message__c>();
                for (Id fatalMessageId : this.FatalIds) fatalities.add(new Message__c(
                    Id = fatalMessageId,
                    Exception__c = asyncApexJob.ExtendedStatus
                ));
                update fatalities;
                
                //next
                this.FatalIds = new Set<Id>();
                this.NextStage = Stage.PersistAndLocateAndMark;
                
            }
            
        } catch (Exception e) {
            this.IsPanic = true; //this will roll over thanks to stateful
            throw e; //first error appears on our AsyncApexJob log
        }
        
    }
    
    public void finish(Database.BatchableContext context) {
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
    
    /**
     * Each Broker implementation must provide the smarts of how to restart it.
     * The VerticalBroker executes another Batch Apex job to run itself again.
     */
    override public void runImpl() {
        if (UserInfo.getUserId() != OAuthSetting__c.getOrgDefaults().RunningUserId__c) {
            //#847 broker panic, wrong user context
            System.assert(false, 'The configured running user Id=[' + UserInfo.getUserId() + '] is null or invalid');
        }
        
        System.scheduleBatch(new VerticalBrokerDispatcher(), 'Enterprise Service Bus Broker', 0, 1);
    }
}