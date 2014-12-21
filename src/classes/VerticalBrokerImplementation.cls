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
    
     private Map<String, Integer>  fullyQualifiedClassNameToLimits = getFullyQualifiedClassNameToLimits();
     
    /**
     * If scope is null, execute will never be reacher!
     * Has to be array of booleans, not nulls
     */
    public Database.QueryLocator start(Database.BatchableContext context) {
        if (BrokerSetting__c.getInstance().Inhibit__c == true) System.assert(false, 'Inhibit'); //INHIBIT
        return Database.getQueryLocator([SELECT Id FROM FieldPermissions LIMIT :RemainingContexts]);
    }
    
    public void execute(Database.BatchableContext context, List<SObject> scopes) {
        if (BrokerSetting__c.getInstance().Inhibit__c == true) System.abortJob(context.getJobId()); //INHIBIT
        
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
        
        // derive chunked and marked messages
        Map<Id,Message__c> chunkedAndMarkedMessages = getChunkedAndMarkedMessages(
            this.markedMessages, 
            this.fullyQualifiedClassNameToLimits
        );

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
        //#653 run Broker under sysadmin user context
        if (Test.isRunningTest()) Database.executeBatch(new VerticalBrokerDispatcher(), 1);
        else restartDefer();
    }
    
    /**
     * Doing this asynchronously to avoid 'uncommitted work pending' exception
     */
    @Future(callout=true) static private void restartDefer() {
        String command = 'Database.executeBatch(new ' + VerticalBrokerDispatcher.class.getName() + '(), 1);';
        
        //using getSalesforceBaseUrl instead of protocolAndHost because the latter requires a session id
        PageReference pr = new PageReference(Url.getSalesforceBaseUrl().toExternalForm() + '/services/data/v32.0/tooling/executeAnonymous');
        pr.getParameters().put('anonymousBody', command);
        String execApex = pr.getUrl();
        
        HttpRequest request = new HttpRequest();
        request.setMethod('GET');
        request.setEndpoint(execApex);
        request.setHeader('Authorization', 'Bearer ' + OAuthSetting__c.getInstance().AccessToken__c);
        
        new Http().send(request);
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



    @testVisible
    private  static Map<String, Integer> getFullyQualifiedClassNameToLimits() {
        Map<String, Integer> results = new Map<String, Integer>();
        for (Process__c process : [SELECT Id, FullyQualifiedClassName__c, Limits__c FROM Process__c]) {
            Integer limits = (process.Limits__c != null) ? (Integer)process.Limits__c : 1; 
            results.put(process.FullyQualifiedClassName__c, limits);
        }
        results.put(null, 1);  
        return results;
    }    


    @testVisible
    private static Map<Id,Message__c> getChunkedAndMarkedMessages(
        Map<Id,Message__c> messageIdToMarkedMessage,
        Map<String,Integer> fullyQualifiedClassNameToLimits
    ) {

        // derive apex class to message collection
        Map<String, Map<Id,Message__c>> fullyQualifiedClassNameToMessageCollection = new Map<String, Map<Id,Message__c>>();
        for (Id messageId : messageIdToMarkedMessage.keySet()) {
            Message__c message = messageIdToMarkedMessage.get(messageId);
            String fullyQualifiedClassName = message.Process__r.FullyQualifiedClassName__c;
            Map<Id,Message__c> messageCollection = fullyQualifiedClassNameToMessageCollection.get(fullyQualifiedClassName);
            if (messageCollection == null) {
                messageCollection = new Map<Id,Message__c>();
            }
            messageCollection.put(messageId,message);
            fullyQualifiedClassNameToMessageCollection.put(fullyQualifiedClassName, messageCollection);
        }

        Map<String, Map<String,Integer>> fullyQualifiedClassNameToAttributes = new Map<String, Map<String,Integer>>();
        for (String fullyQualifiedClassName : fullyQualifiedClassNameToMessageCollection.keySet()) {
            Map<Id,Message__c> messageCollection = fullyQualifiedClassNameToMessageCollection.get(fullyQualifiedClassName);
            Integer messageCount = messageCollection.keySet().size();
            Integer Limits = fullyQualifiedClassNameToLimits.get(fullyQualifiedClassName);  

            Map<String,Integer> attributes = new Map<String,Integer>{
                'Limits' => (Limits == null) ? 0 : Limits,  
                'MessageCount' => messageCount
            };
            
            fullyQualifiedClassNameToAttributes.put(fullyQualifiedClassName ,attributes);
        }

        // make decision 
        String selectedFullyQualifiedClassName = '#UNDEFINED#'; // null is a pseudo valid class name for this logic
        Integer maximumSize = 0;
        for (String fullyQualifiedClassName  : fullyQualifiedClassNameToAttributes.keySet()) {
            Map<String,Integer> attributes = fullyQualifiedClassNameToAttributes.get(fullyQualifiedClassName);
            Integer Limits = attributes.get('Limits');
            Integer messageCount = attributes.get('MessageCount');
            Integer viableCount = (messageCount > Limits) ? Limits : messageCount;
            if (viableCount >= maximumSize) {
                maximumSize = viableCount;
                selectedFullyQualifiedClassName = fullyQualifiedClassName;
            }
        }

        // apply maximum chunks 
        Map<Id,Message__c> results = new Map<Id,Message__c>();
        if (selectedFullyQualifiedClassName != '#UNDEFINED#') {
            Map<Id,Message__c> messageCollection = fullyQualifiedClassNameToMessageCollection.get(selectedFullyQualifiedClassName);
            Map<String,Integer> attributes = fullyQualifiedClassNameToAttributes.get(selectedFullyQualifiedClassName);
            Integer Limits = attributes.get('Limits');
            Integer i = 1;
            for (Id messageCollectionId : messageCollection.keySet()) {
                if (i <= Limits) {
                    results.put(messageCollectionId, messageCollection.get(messageCollectionId));
                }
                i++;
            }
        }
 
        return results;
     }
}