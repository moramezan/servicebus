/**
 * DO NOT ENQUEUE THIS JOB EVER
 * see http://salesforce.stackexchange.com/a/24448/320
 * 
 * This class is WITHOUT SHARING to ensure the process can execute regardless of running user context.
 */
public without sharing class VerticalBrokerImplementation extends Broker implements Database.Batchable<Boolean>, Database.AllowsCallouts, Database.Stateful {
    
    @TestVisible private Set<Id> fatalMessageIds = new Set<Id>();
    @TestVisible private Map<Id,Message__c> markedMessages = new Map<Id,Message__c>();
    @TestVisible private List<Message__c> errorMessages = new List<Message__c>();
    
    @TestVisible private Boolean abortJob = false;

    /**
     * If scope is null, execute will never be reacher!
     * Has to be array of booleans, not nulls
     */
    public Iterable<Boolean> start(Database.BatchableContext context) {
        if (BrokerSettings__c.getInstance().Inhibit__c == true) System.assert(false, 'Inhibit'); //INHIBIT
        return new List<Boolean>{
            true, true, true, true, true, true, true, true, true, true,
            true, true, true, true, true, true, true, true, true, true,
            true, true, true, true, true, true, true, true, true, true,
            true, true, true, true, true, true, true, true, true, true,
            true, true, true, true, true, true, true, true, true, true,
            true, true, true, true, true, true, true, true, true, true,
            true, true, true, true, true, true, true, true, true, true,
            true, true, true, true, true, true, true, true, true, true,
            true, true, true, true, true, true, true, true, true, true,
            true, true, true, true, true, true, true, true, true, true,
            true, true, true, true, true, true, true, true, true, true,
            true, true, true, true, true, true, true, true, true, true,
            true, true, true, true, true, true, true, true, true, true,
            true, true, true, true, true, true, true, true, true, true,
            true, true, true, true, true, true, true, true, true, true,
            true, true, true, true, true, true, true, true, true, true,
            true, true, true, true, true, true, true, true, true, true,
            true, true, true, true, true, true, true, true, true, true,
            true, true, true, true, true, true, true, true, true, true,
            true, true, true, true, true, true, true, true, true, true
        };
    }
    
    public void execute(Database.BatchableContext context, List<Boolean> scopes) {
        if (BrokerSettings__c.getInstance().Inhibit__c == true) System.abortJob(context.getJobId()); //INHIBIT
        
        //ok, so this is kind of awkward... we need SOME OTHER SIGNAL of fatal errors
        //than just the FATAL IDS being "pre set" otherwise those guys never get even
        //a single attempt at execute...  it goes straight from MARK to FATAL HANDLER
        AsyncApexJob asyncApexJob = Test.isRunningTest() ? new AsyncApexJob() : [
            SELECT Id, ExtendedStatus
            FROM AsyncApexJob
            WHERE Id = :context.getJobId()
        ];
        
        //LOCATE
        Database.QueryLocator locator = this.locateMarkableWork(1);
        List<Message__c> markableMessages = new ApexPages.StandardSetController(locator).getRecords();
        
        Boolean hasWorkToMark = !markableMessages.isEmpty();
        Boolean hasWorkToExecute = !this.markedMessages.isEmpty();
        Boolean hasWorkToSaveErrors = !this.errorMessages.isEmpty();
        Boolean hasWorkWithFatalErrors = !this.fatalMessageIds.isEmpty() && asyncApexJob.ExtendedStatus != null;
        
        if (hasWorkWithFatalErrors) {
            //FATAL (sacrificial execution context)
            
            List<Message__c> fatalMessages = new List<Message__c>();
            for (Id fatalMessageId : this.fatalMessageIds) fatalMessages.add(new Message__c(
                Id = fatalMessageId,
                Exception__c = asyncApexJob.ExtendedStatus
            ));
            
            //better than nothing
            update fatalMessages;
            
            //these guys have been handled (fatal)
            this.markedMessages = new Map<Id,Message__c>();
            
            //fatals handled
            this.fatalMessageIds = new Set<Id>();
            
            //next context
            return;
        }
        
        if (hasWorkToSaveErrors) {
            //ERROR (sacrificial execution context)
            update this.errorMessages;
            
            //errors handled
            this.errorMessages = new List<Message__c>();
            
            //next context
            return;
        }
        
        if (!hasWorkToMark && !hasWorkToExecute) {
            //DONE
            if (Test.isRunningTest()) this.abortJob = true; else System.abortJob(context.getJobId());
            
            //last context
            return;
        }
        
        if (!hasWorkToExecute) {
            //MARK
            this.mark(markableMessages);
            this.markedMessages = new Map<Id,Message__c>(markableMessages);
            
            //potentially fatal errors
            this.fatalMessageIds.addAll(this.markedMessages.keySet());
            
            //next context
            return;
        }
        
        List<Message__c> outputMessages;
        try {
        
            //EXECUTE
            outputMessages = this.execute(this.markedMessages.values());
            
            //PERSIST
            this.persist(this.markedMessages.values(), outputMessages);
            
        } catch (EngineException e) {
            
            //revert, except callouts which should really be idempotent anyway
            if (e.savepoint != null) Database.rollback(e.savepoint);
            
            //these had errors
            this.errorMessages = e.fuckups;
            
            //but not fatal errors
            this.fatalMessageIds.removeAll(this.markedMessages.keySet());
            
            //these guys have been handled (failure)
            this.markedMessages = new Map<Id,Message__c>();
            
            //stop, no outputs to resolve
            return;
            
        }
        
        //not fatal errors
        this.fatalMessageIds.removeAll(this.markedMessages.keySet());
        
        //these guys have been handled (successfully)
        this.markedMessages = new Map<Id,Message__c>(); //these guys handled
        
        try {
            
            //RESOLVE
            this.resolve(outputMessages);
            
        } catch (EngineException e) {
            
            //these had errors
            this.errorMessages = e.fuckups;
            
        }
    }
    
    public void finish(Database.BatchableContext context) {
        this.restartIfWorkPending();
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