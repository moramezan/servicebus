/**
 * DO NOT ENQUEUE THIS JOB EVER
 * see http://salesforce.stackexchange.com/a/24448/320
 * 
 * This class is WITHOUT SHARING to ensure the process can execute regardless of running user context.
 */
public without sharing class VerticalBrokerImplementation extends Broker implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    
    @TestVisible private Set<Id> fatalMessageIds = new Set<Id>();
    @TestVisible private Map<Id,Message__c> markedMessages = new Map<Id,Message__c>();
    
    @TestVisible private Boolean abortJob = false;

    /**
     * If scope is null, execute will never be reacher!
     * Has to be array of booleans, not nulls
     */
    public Database.QueryLocator start(Database.BatchableContext context) {
        if (BrokerSettings__c.getInstance().Inhibit__c == true) System.assert(false, 'Inhibit'); //INHIBIT
        return Database.getQueryLocator([SELECT Id FROM FieldPermissions LIMIT 100]);
    }
    
    public void execute(Database.BatchableContext context, List<SObject> scopes) {
        if (BrokerSettings__c.getInstance().Inhibit__c == true) System.abortJob(context.getJobId()); //INHIBIT
        
        //LOCATE
        Database.QueryLocator locator = this.locateMarkableWork(1);
        List<Message__c> markableMessages = new ApexPages.StandardSetController(locator).getRecords();
        
        Boolean hasWorkToMark = !markableMessages.isEmpty();
        Boolean hasWorkToExecute = !this.markedMessages.isEmpty();
        
        if (!hasWorkToMark && !hasWorkToExecute) {
            //DONE
            
            //errors
            this.handleFatalExceptions(context);
            
            //exit
            if (Test.isRunningTest()) this.abortJob = true; else System.abortJob(context.getJobId());
            
            //last context
            return;
        }
        
        if (!hasWorkToExecute) {
            //MARK
            this.mark(markableMessages);
            this.markedMessages = new Map<Id,Message__c>(markableMessages);
            
            //next context
            return;
        }
        
        Set<Id> inputIds = this.markedMessages.keySet();
        List<Message__c> inputMessages = this.markedMessages.values();
        List<Message__c> outputMessages;
        
        //potentially fatal errors
        this.fatalMessageIds.addAll(inputIds);
        
        //these guys have been handled (either way, thanks to stateful)
        this.markedMessages = new Map<Id,Message__c>();
        
        try {
        
            //EXECUTE
            outputMessages = this.execute(inputMessages);
            
            //PERSIST
            this.persist(inputMessages, outputMessages);
            
        } catch (EngineException e) {
            
            //revert, except callouts which should really be idempotent anyway
            if (e.savepoint != null) Database.rollback(e.savepoint);
            
            //these had errors
            update e.fuckups;
            
            //but not fatal errors
            this.fatalMessageIds.removeAll(inputIds);
            
            //stop, no outputs to resolve
            return;
            
        }
        
        //not fatal errors
        this.fatalMessageIds.removeAll(inputIds);
        
        try {
            
            //RESOLVE
            this.resolve(outputMessages);
            
        } catch (EngineException e) {
            
            //these had errors
            update e.fuckups;
            
        }
    }
    
    public void finish(Database.BatchableContext context) {
        this.restartIfWorkPending();
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
        
        //if (asyncApexJob.ExtendedStatus == null) return; //only gonna destroy exception
        
        List<Message__c> fatalMessages = new List<Message__c>();
        for (Id fatalMessageId : this.fatalMessageIds) fatalMessages.add(new Message__c(
            Id = fatalMessageId,
            Exception__c = asyncApexJob.ExtendedStatus
        ));
        
        update fatalMessages;
    }
    
    /**
     * Each Broker implementation must provide the smarts of how to restart it.
     * The BatchBroker executes another Batch Apex job to run itself again.
     */
    override public void restartImpl() {
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