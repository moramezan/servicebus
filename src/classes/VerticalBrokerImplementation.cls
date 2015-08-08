/*
 * DO NOT ENQUEUE THIS JOB EVER
 * see http://salesforce.stackexchange.com/a/24448/320
 *
 * This class is WITHOUT SHARING to ensure the process can execute regardless of running user context.
 */
public without sharing class VerticalBrokerImplementation extends Broker implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    
    @TestVisible private Set<Id> fatalMessageIds = new Set<Id>();
    @TestVisible private Map<Id,Message__c> executableMessages = new Map<Id,Message__c>();
    @TestVisible private List<Message__c> persistableMessages = new List<Message__c>();
    @TestVisible private Boolean abortJob = false;
    
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
    @TestVisible private Boolean isHaywire = false;
    
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
        //#690 prevent haywire (do NOT try to persist errors)
        if (this.isHaywire) {
            System.abortJob(context.getJobId());
            return;
        }
        
        //ever decreasing
        this.Contexts--;
        
        //PERSIST only if we are immediately after an EXECUTE
        if (!this.persistableMessages.isEmpty()) {
            this.persist(this.persistableMessages); //#778
            //no return, carry on and mark...
        }
        
        //handle errors progressively
        if (!this.fatalMessageIds.isEmpty()) {
            //dedicate this whole context to fatal exception handling
            this.handleFatalExceptions(context);
            return;
        }
        
        Boolean hasWorkToExecute = !this.executableMessages.isEmpty();
        Boolean isExecuteContext = hasWorkToExecute;
        
        Boolean hasWorkToMark = false;
        Boolean isMarkContext = false;
        
        List<Message__c> markableMessages;
        if (!isExecuteContext) {
            //LOCATE but only if we are not in user execute context
            try {
                markableMessages = this.locateMarkableWork();
            } catch (Exception e) {
                this.isHaywire = true; //this will roll over thanks to stateful
                throw new Broker.EngineException('Locate haywire condition: ' + e.getMessage());
            }
            
            hasWorkToMark = !markableMessages.isEmpty();
            isMarkContext = hasWorkToMark && !hasWorkToExecute;
        }
        
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
                this.persistableMessages = new List<Message__c>();
                List<Message__c> outputMessages = new List<Message__c>();
                this.execute(inputMessages, outputMessages);
                
                //#778 not quite PERSIST
                this.persistableMessages.addAll(inputMessages);
                this.persistableMessages.addAll(outputMessages);
                
            } catch (Exception e) {
                throw e;
                for (Message__c inputMessage : inputMessages) {
                    inputMessage.Exception__c = e.getMessage().abbreviate(SObjectType.Message__c.Fields.Exception__c.Length);
                    inputMessage.Cause__c = new ExceptionSerializer(e).getAsString().abbreviate(SObjectType.Message__c.Fields.Cause__c.Length);
                }
                
                //these had errors
                update inputMessages;
            }
            
            //ultimately not fatal errors
            this.fatalMessageIds.removeAll(inputIds);
        }
    }
    
    public void finish(Database.BatchableContext context) {
        super.run();
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
    override public void runImpl() {
        if (UserInfo.getUserId() != OAuthSetting__c.getOrgDefaults().RunningUserId__c) {
            //#847 broker panic, wrong user context
            System.assert(false, 'The configured running user Id=[' + UserInfo.getUserId() + '] is null or invalid');
        }
        
        System.scheduleBatch(new VerticalBrokerDispatcher(), 'Enterprise Service Bus Broker', 0, 1);
    }
}