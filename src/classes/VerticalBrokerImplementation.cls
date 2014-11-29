/*
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
     * some integer below a hard limit of 4000 (min expected rows in FieldPermissions)
     */
    @testVisible
    private  Integer RemainingContexts = 100;   

    /**
     * experiment esp when chunking - for now, set at 50% of RemainingContexts 
     */
    @testVisible
    private static Integer TotalPotentialMarks = 50;  

     @testVisible
     private  Boolean hasAllContexts = true;
     
    /**
     * If scope is null, execute will never be reacher!
     * Has to be array of booleans, not nulls
     */
    public Database.QueryLocator start(Database.BatchableContext context) {
        if (BrokerSettings__c.getInstance().Inhibit__c == true) System.assert(false, 'Inhibit'); //INHIBIT
        return Database.getQueryLocator([SELECT Id FROM FieldPermissions LIMIT :RemainingContexts]);
    }
    
    public void execute(Database.BatchableContext context, List<SObject> scopes) {
        if (BrokerSettings__c.getInstance().Inhibit__c == true) System.abortJob(context.getJobId()); //INHIBIT
        
        //LOCATE
        Database.QueryLocator locator = this.locateMarkableWork(TotalPotentialMarks);
        List<Message__c> markableMessages = new ApexPages.StandardSetController(locator).getRecords();
        
        Boolean hasWorkToMark = !markableMessages.isEmpty();
        Boolean hasWorkToExecute = !this.markedMessages.isEmpty();
        
        RemainingContexts--;
                
        if (!hasAllContexts) {
            //DONE
            
            //last context
            if (RemainingContexts == 0) {
                //errors
                this.handleFatalExceptions(context); 
                
                return; 
            }
        }
        
        if (!hasWorkToMark && !hasWorkToExecute)  {
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
            if (hasAllContexts) { // this flag is set to false inside this code block ..
                // at this point, taking account of 
                //  - contexts  already executed (incl. this context)
                //  - the need for a terminate context
                //  - the combined work executes of markableMessages and  markedMessages  
                // how many contexts are actually available ?
                Integer availableContexts = getAvailableContexts(RemainingContexts ,  markableMessages,  markedMessages);
                
                // limit the markable messages to actually available "WorkToExecute" contexts
                List<Message__c> adjustedMarkableMessages = getAdjustedMarkableMessages(markableMessages, availableContexts+1);
                
                // set the terminate flag
                hasAllContexts = (availableContexts > 0);
                
                // if  (adjusted) markable Messages exist
                //   - mark these guys in the database 
                //  - simultaneously add them to the  stateful markedMessages collection
                if (adjustedMarkableMessages.size() > 0) {
                    this.mark(adjustedMarkableMessages);
                    Map<Id,Message__c> messageIdToMarkableMessage = new Map<Id,Message__c>(adjustedMarkableMessages);
                    for (Id markableMessageId : messageIdToMarkableMessage.keySet()) {
                        this.markedMessages.put(markableMessageId, messageIdToMarkableMessage.get(markableMessageId));
                    }
                }
            }
 
            //next context
            return;
        }
        
        Map<Id,Message__c> chunkedAndMarkedMessages = getChunkedAndMarkedMessages(this.markedMessages);
        ////
        Set<Id> inputIds = chunkedAndMarkedMessages.keySet();
        List<Message__c> inputMessages = chunkedAndMarkedMessages.values();  
        List<Message__c> outputMessages;
        
        //potentially fatal errors
        this.fatalMessageIds.addAll(inputIds);
        
        //marked messages not selected for execution in this context
        this.markedMessages =   getRemainingMarkedMessages(this.markedMessages,chunkedAndMarkedMessages);

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
     * The VerticalBroker executes another Batch Apex job to run itself again.
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

    @testVisible
    private static Map<Id,Message__c> getChunkedAndMarkedMessages(Map<Id,Message__c> markedMessages) {
        // for this implementation, simply pull and return the first available message
        Map<Id,Message__c> results = new Map<Id,Message__c>();
        if (markedMessages.size() > 0) {
            results.put(markedMessages.values()[0].Id , markedMessages.values()[0]);    
        }
        return results;
    }

    @testVisible
    private static Map<Id,Message__c> getRemainingMarkedMessages(
        Map<Id,Message__c> markedMessages,
        Map<Id,Message__c> chunkedAndMarkedMessages
    ) {
        Map<Id,Message__c> remainingMarkedMessages = new Map<Id,Message__c>();
        for (Id messageId : markedMessages.keySet()) {
            if (!chunkedAndMarkedMessages.keySet().contains(messageId)) {
                remainingMarkedMessages.put(messageId, markedMessages.get(messageId));
            }
        }
        return remainingMarkedMessages;
    }
    
    @testVisible
    private static Integer getAvailableContexts (
        Integer remainingContexts, 
        List<Message__c> markableMessages,
        Map<Id,Message__c> markedMessages 
    ) {
        Integer exitContext = 1;
        return remainingContexts - markableMessages.size() - markedMessages.size() - exitContext;
    }
    
    /**
     * if we cant do the full MarkableMessage complement (ie messages selected with Buffered state),
     * can we instead try to do as many as we can given the available remaining contexts
     */
    @testVisible
    private static List<Message__c> getAdjustedMarkableMessages(
        List<Message__c> markableMessages, 
        Integer availableContexts
    ) {
        if (markableMessages.size() <= availableContexts) {
            return markableMessages;
        }
 
        List<Message__c> adjustedMarkableMessages = new List<Message__c>();
        Integer i = 1;
        while (i <= availableContexts) {
            adjustedMarkableMessages.add(markableMessages[i-1]);
            i++;
        }

        return adjustedMarkableMessages;
    }
}