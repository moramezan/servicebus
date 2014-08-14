/**
 * DO NOT ENQUEUE THIS JOB EVER
 * see http://salesforce.stackexchange.com/a/24448/320
 * 
 * This class is WITHOUT SHARING to ensure the process can execute regardless of running user context.
 */
public without sharing class BatchBrokerImplementation extends Broker implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    
    /**
     * Holds processable Message Ids for the sake of writing away unhandled exceptions
     * We start with all the processable Message Ids and subtract the successful ones.
     */
    private Set<Id> failedMessageIds = new Set<Id> ();
    
    public Database.QueryLocator start(Database.BatchableContext context) {
        if (BrokerSettings__c.getInstance().Inhibit__c == true) System.assert(false, 'Inhibit'); //INHIBIT
        
        //LOCATE
        Database.QueryLocator locator = this.locateMarkableWork(100);
        List<Message__c> messages = new ApexPages.StandardSetController(locator).getRecords();
        
        //MARK
        this.mark(messages);
        
        //assume all of them failing
        this.failedMessageIds = new Map<Id,Message__c>(messages).keySet();
        
        return locator;
    }
    
    public void execute(Database.BatchableContext context, List<Message__c> inputMessages) {
            //EXECUTE
            List<Message__c> outputMessages = this.execute(inputMessages);
            
            //RESOLVE
            this.resolve(outputMessages);
            
            //PERSIST
            this.persist(inputMessages, outputMessages);
        
        //incrementally remove non failing message ids
        for (Message__c inputMessage : inputMessages) this.failedMessageIds.remove(inputMessage.Id);
    }
    
    public void finish(Database.BatchableContext context) {
        //any error detail is not on the batch job now, so look it up a little later
        if (!this.failedMessageIds.isEmpty()) this.deferExceptionHandler(context.getJobId(), this.failedMessageIds);
        
        this.restartIfWorkPending();
    }
    
    /**
     * Would prefer to do this in a @Future but that's not permitted from Batch
     * so we schedule a job that runs (almost) immediately to go persist the errors.
     * 
     * The new reason we can't persist such errors in the execute() method is
     * because we aren't catching any exceptions... because we can't do savepoints...
     * because we can't do DML... because it prevents user processes doing callouts!
     *
     * Leaving the exceptions unhandled blesses us with system wide 'automatic rollback'
     * as we can't call Database.setSavepoint(). Less naughty than leaving side effects
     * or requiring every single process to implement its own transaction management.
     */
    @TestVisible private void deferExceptionHandler(Id asyncApexJobId, Set<Id> failedMessageIds) {
        //1 second is not enough, we hit 'Based on configured schedule, the given trigger will never fire.'
        DateTime now = System.now().addSeconds(5);
        String cron = now.second() + ' ' + now.minute() + ' ' + now.hour() + ' ' + now.day() + ' ' + now.month() + ' ' + '?' + ' ' + now.year();
        BatchBrokerExceptionHandlerSchedule schedule = new BatchBrokerExceptionHandlerSchedule(asyncApexJobId, failedMessageIds);
        System.schedule('Exception handler for ' + asyncApexJobId, cron, schedule);
    }
    
    /**
     * Each Broker implementation must provide the smarts of how to restart it.
     * The BatchBroker executes another Batch Apex job to run itself again.
     */
    override public void restartImpl() {
        Database.executeBatch(new BatchBrokerDispatcher(), 1);
    }
    
    override public Boolean isAlreadyRunning() {
        System.Type type = BatchBrokerDispatcher.class;
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