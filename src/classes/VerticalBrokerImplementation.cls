/**
 * DO NOT ENQUEUE THIS JOB EVER
 * see http://salesforce.stackexchange.com/a/24448/320
 * 
 * This class is WITHOUT SHARING to ensure the process can execute regardless of running user context.
 */
public without sharing class VerticalBrokerImplementation extends Broker implements Database.Batchable<Boolean>, Database.AllowsCallouts, Database.Stateful {
    
    @TestVisible private List<Message__c> markedMessages = new List<Message__c>();
    @TestVisible private Boolean abortJob = false;

    class Generator implements Iterable<Boolean>,Iterator<Boolean> {
        private Integer i = 0;
        public Boolean hasNext() {
            if (i > 100) return false;
            return true;
        }
        public Boolean next() {
            i++;
            return true;
        }
        public Iterator<Boolean> iterator() {
            return this;
        }
    }
    
    /**
     * If scope is null, execute will never be reacher!
     * Has to be array of booleans, not nulls
     */
    public Iterable<Boolean> start(Database.BatchableContext context) {
        if (BrokerSettings__c.getInstance().Inhibit__c == true) System.assert(false, 'Inhibit'); //INHIBIT
        
        return (Iterable<Boolean>)new Generator();
    }
    
    public void execute(Database.BatchableContext context, List<Boolean> scopes) {
        if (BrokerSettings__c.getInstance().Inhibit__c == true) System.abortJob(context.getJobId()); //INHIBIT
        
        //LOCATE
        Database.QueryLocator locator = this.locateMarkableWork(1);
        List<Message__c> markableMessages = new ApexPages.StandardSetController(locator).getRecords();
        
        Boolean hasWorkToMark = !markableMessages.isEmpty();
        Boolean hasWorkToExecute = !this.markedMessages.isEmpty();
        
        if (!hasWorkToMark && !hasWorkToExecute) {
            //DONE
            if (Test.isRunningTest()) this.abortJob = true; else System.abortJob(context.getJobId());
            
            //last context
            return;
        }
        
        if (!hasWorkToExecute) {
            //MARK
            this.mark(markableMessages);
            this.markedMessages = markableMessages;
            
            //next context
            return;
        } else {
            List<Message__c> inputMessages = this.markedMessages;
            
            //EXECUTE
            List<Message__c> outputMessages = this.execute(inputMessages);
            this.markedMessages = new List<Message__c>(); //these guys handled
            
            //RESOLVE
            this.resolve(outputMessages);
            
            //PERSIST
            this.persist(inputMessages, outputMessages);
            
            //next context
            return;
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