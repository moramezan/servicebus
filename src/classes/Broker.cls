/**
 * Very fundamental order:
 *
 * Example sequence:
 * Test#1 [Wiretap]
 * Test#2 [Terminate]
 *
 * [interactive] System.enqueueJob(job)
 * [queueable] execute job
 * [future] call tooling api
 * [tooling] System.scheduleBatch(broker)
 * [schedule] ...wait...
 * [batch.start]
 * [batch.execute] broker.locate() then broker.mark(wiretap)
 * [batch.execute] broker.execute(wiretap)
 * [batch.execute] broker.locate() then broker.persist(wiretap) then broker.mark(terminate)
 * [batch.execute] broker.execute(terminate)
 * [batch.execute] broker.locate() then abort()
 */
/**
 * This class is WITHOUT SHARING to ensure the process can execute regardless of running user context.
 */
abstract public without sharing class Broker {
    
    /**
     * #985 helps avoid misleading errors
     */
    public Integer BlameCpuTime;
    public String BlameRoute;
    
    static public Integer MaximumHops = 1000;
    
    public class UserException extends Exception {}
    public class PanicException extends Exception {}
    
    static public Broker impl() {
        if (Test.isRunningTest()) {
            //unit test broker
            return new BrokerTest.SynchronousBroker();
        } else {
            //production broker
            return new BrokerImplementation();
        }
    }
    
    /**
     * Determines which messages are eligible to be moved into the Started status (by finding Messages
     * with 'Buffered' status).
     *
     * Messages that should be processed have their status marked as Started in the database before being
     * submitted the query locator. That way, if any given execution fails, those messages will remain in the
     * easily identifiable 'Started' state.
     *
     * CONTEXT A:
     * - Persist (from previous)
     * - Locate (lock for update)
     * - Mark (performs update and puts into stateful, safe from clutches of other jobs)
     *
     * CONTEXT B:
     * - Execute (reads guys off stateful property, does work and performs update)
     *
     * @return collection of soon-to-be-marked-as-Started Messages.
     */
    public List<Message__c> locateMarkableWork() {
        try {
            List<Message__c> specimen = [
                SELECT Id, Route__c, Event__c //TODO lose event?
                FROM Message__c
                WHERE Status__c = 'Buffered'
                ORDER BY CreatedDate ASC //reattempts will naturally lead
                LIMIT 1
                //TODO: this guy should be FOR UPDATE or risk race condition
            ];
            
            //TODO fucked limits COULD be high if we want performance vs risk
            
            if (specimen.isEmpty()) {
                //no work found, return empty
                return specimen;
            }
            
            ApexClassModel.Summary summary;
            
            try {
                //we have to 'peek' at the process
                ApexClassModel model = new MessageModel(specimen[0]).resolveApexClassModel();
                summary = new ApexClassModel.Summary(model.Reflector);
            } catch (Exception e) {
                //could not resolve, limits 1
                return specimen;
            }
            
            Integer limits = summary.Limits;
            
            //TODO what if this guy returns a list of 0, would cause a panic condition, lets check
            
            return [
                SELECT Id, Route__c, Event__c //TODO lose event?
                FROM Message__c
                WHERE Status__c = 'Buffered'
                AND Route__c = :specimen[0].Route__c //#1004 Route__c field only ever used here to LOCATE, and for GATE and MONITOR
                LIMIT :limits
                FOR UPDATE //#695 investigate broker race condition
            ];
            
        } catch (Exception e) {
            throw new PanicException('Locate panic: ' + e.getMessage(), e);
        }
    }
    
    /**
     * Sets many Messages statuses to 'Started' and writes them away.
     */
    public List<Database.SaveResult> mark(List<Message__c> messages) {
        try {
            if (!SObjectType.Message__c.Fields.Status__c.Updateable) throw new ApexDomain.FlsException('!SObjectType.Message__c.Fields.Status__c.Updateable');
            for (Message__c message : messages) message.Status__c = 'Started'; //in-database
            List<Database.SaveResult> results = Database.update(messages);
            return results;
            
        } catch (Exception e) {
            throw new PanicException('Mark panic: ' + e.getMessage(), e);
        }
    }
    
    /**
     * Resolves and invokes the toStringable Object for one input, updating an in-memory collection of outputs
     *
     * @param  inputMessages pass-by-reference Messages whose status should be Started
     * @param  outputMessages pass-by-reference Messages whose status should be Started
     */
    public void execute(List<Message__c> inputMessages, List<Message__c> outputMessages) {
        try {
            //empty inputs, empty outputs
            if (inputMessages.isEmpty()) return;
            
            Integer chunkTotal = inputMessages.size();
            Integer chunk = 1;
            for (Message__c inputMessage :  inputMessages) {
                Map<String,Object> inputEvent = (Map<String,Object>)Json.deserializeUntyped(inputMessage.Event__c);
                inputEvent.put('Range', chunkTotal);
                inputEvent.put('Chunk', chunk);
                inputMessage.Event__c = Json.serializePretty(inputEvent);
                chunk++;
            }
            
            //OUR FUCKUPS (prepare)
            List<MessageModel> models = new List<MessageModel>();
            for (Message__c inputMessage : inputMessages) {
                MessageModel model = new MessageModel(inputMessage);
                models.add(model);
            }
            
            //THEIR FUCKUPS (callout)
            for (MessageModel model : models) {
                //do invocation
                this.BlameCpuTime = Limits.getCpuTime(); //#985
                this.BlameRoute = (String)model.Event.get('Route'); //#985
                model.invokeCallout();
            }
            
            //for isolating chunks from each other
            Savepoint sp = Database.setSavepoint();
            Boolean isolate = false;
            
            //THEIR FUCKUPS (execute)
            for (MessageModel model : models) {
                
                if (isolate) {
                    //consume savepoint only if necessary (side effects)
                    sp = Database.setSavepoint();
                    isolate = false;
                }
                
                //do invocation
                this.BlameCpuTime = Limits.getCpuTime(); //#985
                this.BlameRoute = (String)model.Event.get('Route'); //#985
                isolate = model.invokeExecute(outputMessages);
                
                if (model.Message.Exception__c != null && isolate) {
                    //consume rollback only if necessary (error AND side effects)
                    Database.rollback(sp);
                }
            }
            
        } catch (Exception e) {
            throw new PanicException('Execute panic:' + e.getMessage(), e);
        }
    }

    /**
     * #782
     *
     * Maybe we can entertain this :( because this method is now PUBLIC and not GLOBAL.
     *
     * We used to have two arguments for inputMessages and outputMessages. The idea being:
     * that inputMessages were all gonna be written away as "Completed"
     * and outputMessages were all gonna be written away as "Buffered"
     * (ka-chunk)
     *
     * But the checkmarx scanner chokes "Bulkify_Apex_Methods_Using_Collections_In_Methods"
     * which Salesforce have confirmed to be a bug... however it requires a human to do that.
     *
     * To keep the amount of back and forth and delay to a minimum, we can get away with merging
     * the two collections into one, and doing all the status changes in memory:
     * the inputMessages get "Completed" by mark()
     * and outputMessages get "Buffered" by execute()
     *
     *
     */
    public void persist(List<Message__c> inputAndOutputMessages) {
        try {
            
            /**
             * In #658 we hoped to expose Sequence API in Broker.persist() since
             * that is the central entry point for any enqueued AND output messages.
             *
             * Since #677 there is history around which operations belong where:
             * - Process does bare metal input cycling, output aggregation,
             * - ApexClassModel can enforce validation at the event level,
             * - MessageModel takes grabs exceptions for the database,
             * - Broker deals with executing message collections,
             *
             * Since we want any "resolve" to happen in ONE place, this appears to
             * be the only place left to put it. Here in the persist works OK because
             * messages "without ids" are NEW ONES. Existing ones won't get re incremented.
             */
            for (Message__c message : inputAndOutputMessages) if (message.Id == null) {
                Map<String,Object> event = (Map<String,Object>)Json.deserializeUntyped(message.Event__c);
                
                //increments route position
                if (event.containsKey('Route')) {
                    String route = (String)event.get('Route');
                    String sequence = route.substringBefore('#');
                    String position = route.substringAfter('#');
                    if (route.contains('#')) event.put('Route', sequence + '#' + (Integer.valueOf(position) + 1));
                }
                
                message.Event__c = Json.serialize(event);
            }
            
            //transact both inputs and outputs in one fell swoop
            MessageSetModel.Inhibit = false;
            Database.upsert(inputAndOutputMessages);
            MessageSetModel.Inhibit = true;
            
        } catch (Exception e) {
            throw new PanicException('Persist panic: ' + e.getMessage(), e);
        }
    }
    
    /**
     * Formerly restartIfWorkPending
     * The VerticalBroker executes another Batch Apex job to run itself again.
     *
     * Per #929 we can use System.scheduleBatch to NAME THE JOB which lets us
     * lean on the platform to prevent races. Salesforce will block second job!
     *
     * If you try and schedule TWO jobs in ONE execution context:
     * System.AsyncException: The Apex job named 'test' is already scheduled for execution.
     *
     * Or if you scheduled ONE job in each of TWO execution contexts:
     * System.UnexpectedException: common.exception.SqlDupValOnIndexException: ORA-00001: unique constraint (CORE.AKCRON_JOB_DETAIL) violated
     *
     * We see one of the seven dwarves appearing too:
     * ORA-06512: at "HAPPY.UDDDMLCRONJOBDETAIL", line 32
     * ORA-06512: at "HAPPY.CCRONJOBDETAIL", line 95
     * ORA-06512: at line 1
     * {call cCronJobDetail.insert_detail(?,?,?,?,?,?,?,?,?,?,?)}
     * {call cCronJobDetail.insert_detail(?,?,?,?,?,?,?,?,?,?,?)}
     */
    public void run() {
        if (BrokerSetting__c.getOrgDefaults().Inhibit__c) {
            //INHIBIT
            System.assert(false, 'Inhibit');
        }
        
        if ([SELECT Id FROM Message__c WHERE Status__c = 'Buffered' LIMIT 1].isEmpty()) {
            //nothing to do
            return;
        }
        
        this.runImpl();
        
    }
    
    abstract public void runImpl();
    
    static public Boolean isAllowedSessionId(String reflectorName, Id orgId) {
        if (!Test.isRunningTest() && Broker.class.getName() == 'Broker') return true; //unmanaged deployment ok
        
        Set<String> sessionIdOrgs = new Set<String>{
            '00Dj0000000I44v', // dev org - matt
            '00Dj0000001oeWV', // dev org - neil
            '00Dj0000001q22l', // dev org - harsha
            '00Do0000000dQSB', // dev org - natani
            '00Dj0000001uJgw'  // dev org - tom
        };
        Set<String> sessionIdNamespaces = new Set<String>{
            'esb',
            'esb_batchpdf',
            'esb_tooling',
            'esb_metadata'
        };
        String namespacePrefix  = reflectorName.subStringBefore('.');
        String orgId15 = String.valueOf(orgId).left(15);
 
        return sessionIdOrgs.contains(orgId15) || sessionIdNamespaces.contains(namespacePrefix);
    }
}