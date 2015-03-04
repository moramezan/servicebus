/*
 * DO NOT ENQUEUE THIS JOB EVER
 * see http://salesforce.stackexchange.com/a/24448/320
 * 
 * This class is WITHOUT SHARING to ensure the process can execute regardless of running user context.
 */
public without sharing class VerticalBrokerImplementation extends Broker implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    
    @TestVisible private Set<Id> fatalMessageIds = new Set<Id>();
    @TestVisible private Map<Id,Message__c> executableMessages = new Map<Id,Message__c>();
    @TestVisible private Boolean abortJob = false;

    /**
     * If we encounter any kind of unexpected exception (catchable or otherwise)
     * inside this batch job, we risk that the QueryLocator will loop forever. This
     * flag can be set when that condition is detected.
     */
    @TestVisible private Boolean isHaywire = false;
    
    /**
     * Some integer below a hard limit of 4000 (min expected rows in FieldPermissions)
     */
    @TestVisible private Integer Contexts = 1000;
    
    public VerticalBrokerImplementation() {
        // #671 first query locator spends less time in 'Preparing'
        if (Broker.IsFirstRun) this.Contexts = 50;
    }
    
    /**
     * If scope is null, execute will never be reacher!
     * Has to be array of booleans, not nulls
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
        //#690 prevent haywire (do NOT try to persist errors)
        if (this.isHaywire) {
            System.abortJob(context.getJobId());
            return;
        }
        
        //ever decreasing
        this.Contexts--;
        
        //handle errors progressively
        if (!this.fatalMessageIds.isEmpty()) {
            //dedicate this whole context to fatal exception handling
            this.handleFatalExceptions(context);
            return;
        }
        
        //LOCATE
        List<Message__c> markableMessages;
        try {
            markableMessages = this.locateMarkableWork();
        } catch (Exception e) {
            this.isHaywire = true; //this will roll over thanks to stateful
            throw new Broker.EngineException('Locate haywire condition: ' + e.getMessage());
        }
        
        Boolean hasWorkToMark = !markableMessages.isEmpty();
        Boolean hasWorkToExecute = !this.executableMessages.isEmpty();
        
        Boolean isMarkContext = hasWorkToMark && !hasWorkToExecute;
        Boolean isExecuteContext = hasWorkToExecute;
        Boolean isAbortJobContext = !hasWorkToMark && !hasWorkToExecute;
        Boolean isNeedsMoreContexts = this.Contexts == 0;
        
        //MORE
        if (isNeedsMoreContexts) {
            //no point to mark OR execute, just restart
            return;
        }
        
        //ABORT
        if (isAbortJobContext) {
            //exit
            if (Test.isRunningTest()) this.abortJob = true; else System.abortJob(context.getJobId());
        }
        
        //MARK
        if (isMarkContext) {
            //but if we can't execute, don't mark
            if (this.Contexts == 1) return;
            
            try {
                //put these guys ready to handle
                this.mark(markableMessages);
                this.executableMessages = new Map<Id,Message__c>(markableMessages);
                
            } catch (Exception e) {
                this.isHaywire = true; //this will roll over thanks to stateful
                throw new Broker.EngineException('Mark haywire condition: ' + e.getMessage());
            }
        }
        
        //EXECUTE
        if (isExecuteContext) {
            
            Set<Id> inputIds = this.executableMessages.keySet();
            List<Message__c> inputMessages = this.executableMessages.values();
            
            //clear these guys as handled (successfully or otherwise, thanks to stateful)
            this.executableMessages = new Map<Id,Message__c>();
            
            //potentially fatal errors
            this.fatalMessageIds.addAll(inputIds);
            
            try {
                //EXECUTE
                List<Message__c> outputMessages = this.execute(inputMessages);
                
                //PERSIST
                List<Message__c> inputAndOutputMessages =  new List<Message__c>();
                inputAndOutputMessages.addAll(inputMessages);
                inputAndOutputMessages.addAll(outputMessages);
                this.persist(inputAndOutputMessages); //#782
                
            } catch (EngineException e) {
                //revert, except callouts which should really be idempotent anyway
                if (e.savepoint != null) Database.rollback(e.savepoint);
                
                //these had errors
                update e.fuckups;
            }
            
            //ultimately not fatal errors
            this.fatalMessageIds.removeAll(inputIds);
        }
    }
    
    public void finish(Database.BatchableContext context) {
        this.restartIfWorkPending();
    }
    
    public void handleHaywireCondition(Database.BatchableContext context) {
        System.abortJob(context.getJobId());
        //throw new Broker.EngineException('Haywire condition!');
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
    public void handleFatalExceptions(Database.BatchableContext context) {
        if (this.fatalMessageIds.isEmpty()) return;
        
        AsyncApexJob asyncApexJob = [
            SELECT Id, ExtendedStatus
            FROM AsyncApexJob
            WHERE Id = :context.getJobId()
        ];
        
        List<Message__c> fatalMessages = new List<Message__c>();
        for (Id fatalMessageId : this.fatalMessageIds) fatalMessages.add(new Message__c(
            Id = fatalMessageId,
            Exception__c = asyncApexJob.ExtendedStatus.abbreviate(SObjectType.Message__c.Fields.Exception__c.Length) //#754
        ));
        
        update fatalMessages;
        
        //empty out
        this.fatalMessageIds = new Set<Id>();
    }
    
    /**
     * Each Broker implementation must provide the smarts of how to restart it.
     * The VerticalBroker executes another Batch Apex job to run itself again.
     */
    override public void restartImpl() {
        //#653 run Broker under sysadmin user context
        Database.executeBatch(new VerticalBrokerDispatcher(), 1);
    }
    
    override public Boolean isAlreadyRunning() {
        System.Type type = VerticalBrokerDispatcher.class;
        String namespacePrefix;
        String name;
        
        if (type.getName().contains('.')) {
            //managed (namespaceprefix.classname)
            namespacePrefix = type.getName().substringBefore('.');
            name = type.getName().substringAfter('.');
        } else {
            //unmanaged (classname)
            namespacePrefix = '';
            name = type.getName();
        }
        
        //find existing jobs
        Integer existingJobsCount = [
            SELECT COUNT()
            FROM AsyncApexJob
            WHERE ApexClass.NamespacePrefix = :namespacePrefix AND ApexClass.Name = :name
            AND JobType IN ('BatchApex')
            AND Status IN ('Queued', 'Processing', 'Preparing')
        ];
        
        return existingJobsCount != 0;
    }

}