/**
 * Very fundamental order:
 *
 * Example sequence:
 * TestSequence #1 [Wiretap]
 * TestSequence #2 [Wiretap]
 * TestSequence #3 [Terminate]
 *
 * As used by a queueing broker:
 *
 * +-----------+ (CONTEXT 1 FROM USER)
 * |  ENQUEUE  |
 * +-----------+
 *
 * +-----------+ (CONTEXT 2 batchable.start)
 * |  MARK     | we need to "dirty" these guys with Started status in case they fuck up
 * +-----------+
 *
 * +-----------+ (CONTEXT 3 batchable.execute)
 * |  EXECUTE  | invokes [Wiretap]
 * |  RESOLVE  | ensures all generated messages never
 * |  PERSIST  | exist in an unresolved state per issue #100
 * +-----------+
 *
 * +-----------+ (CONTEXT 4 batchable.finish)
 * |  ENQUEUE  |
 * +-----------+
 *
 * +-----------+ (CONTEXT 5 batchable.start)
 * |  MARK     |
 * +-----------+
 *
 * +-----------+ (CONTEXT 6 batchable.execute)
 * |  EXECUTE  | invokes [Wiretap]
 * |  RESOLVE  |
 * |  PERSIST  |
 * +-----------+
 *
 * +-----------+ (CONTEXT 7 batchable.finish)
 * |  ENQUEUE  |
 * +-----------+
 *
 * +-----------+ (CONTEXT 8 batchable.start)
 * |  MARK     |
 * +-----------+
 *
 * +-----------+ (CONTEXT 9 batchable.execute)
 * |  EXECUTE  | invokes [Terminate]
 * |  RESOLVE  |
 * |  PERSIST  |
 * +-----------+
 *
 * +-----------+ (CONTEXT 10 batchable.finish)
 * |  ENQUEUE  |
 * +-----------+
 *
 *
 *
 * As used by a synchronous broker:
 *
 * +-----------+ (CONTEXT 1 FROM USER)
 * |  ENQUEUE  |
 * |           |
 * |  RESOLVE  |
 * |  PERSIST  |
 * |  MARK     |
 * |  EXECUTE  | invokes [Wiretap]
 * |  RESOLVE  |
 * |  PERSIST  |
 * |  MARK     |
 * |  EXECUTE  | invokes [Wiretap]
 * |  RESOLVE  |
 * |  PERSIST  |
 * |  MARK     |
 * |  EXECUTE  | invokes [Terminate]
 * +-----------+
 */
abstract global with sharing class Broker {
    
    @TestVisible private static Integer stackDepthThreshold  = 500;
    
    global class EngineException extends Exception {}
    
    public class CrudException extends Exception {}
    
    public class FlsException extends Exception {}
    
    static public Broker impl() {
        //first try to resolve broker class from custom setting
        BrokerSettings__c settings = BrokerSettings__c.getInstance();
        
        //if there is no setting, use the default batch broker
        if (settings.BrokerClassName__c == null) settings.BrokerClassName__c = BatchBrokerImplementation.class.getName(); 
        
        //new up and return the broker instance
        Broker impl = (Broker)Type.forName(settings.BrokerClassName__c).newInstance();
        return impl;
    }

    @TestVisible static private List<Map<String,Object>> invoke(Type reflector, Map<String,Object> input) {
        //cast inputs and invoke
        Map<String,Object> untyped = new Map<String,Object>{
            'Parameters' => Json.serialize(input)
            //AllowsCallouts
        };
        Object process = Json.deserialize(Json.serialize(untyped), reflector);
        String data = String.valueOf(process);
        List<Object> results = (List<Object>)Json.deserializeUntyped(data);

        //balance plus delta, cast output
        List<Map<String,Object>> outputs = new List<Map<String,Object>>();
        for (Object result : results) {
            Map<String,Object> output = input.clone();
            output.putAll((Map<String,Object>)result);
            outputs.add(output);
        }

        return outputs;
    }

    /**
     * Determines which messages are eligible to be moved into the Started status (by finding Messages
     * with 'Rebuffered' and 'Buffered' status). Note: too many fucked messages would clog up the system,
     * so we have a global fuckedLimit.
     *
     * Messages that should be processed have their status marked as Started in the database before being
     * submitted the query locator. That way, if any given execution fails, those messages will remain in the
     * easily identifiable 'Started' state.
     *
     * @param workCount Maximum number of Messages to mark and locate (subject to fuckups)
     * @return          Query Locator identifying the now-marked-as-Started Messages.
     */
    virtual global Database.QueryLocator locateMarkableWork(Integer workCount) {
        Integer fuckedLimit = 100;
        
        Integer fuckedCount = [
            SELECT COUNT()
            FROM Message__c
            WHERE Status__c = 'Started'
        ];
        
        Integer rebufferedCount = [
            SELECT COUNT()
            FROM Message__c
            WHERE Status__c = 'Rebuffered'
        ];
        
        //derives maximum number of Messages available for starting
        Integer queryLimit = Math.max(0, fuckedLimit - fuckedCount) + rebufferedCount;
        
        Set<Id> messageIds = new Map<Id,Message__c>([
            SELECT Id
            FROM Message__c
            WHERE Status__c IN ('Rebuffered', 'Buffered')
            ORDER BY Status__c DESC
            LIMIT :Math.min(workCount, queryLimit)
        ]).keySet();
        
        //query locator hands back only the messages that are markable as Started
        String commaDelimitedIds = '(\'' + String.join(new List<Id>(messageIds), '\',\'') + '\')';
        String queryString = 'SELECT Id, Step__c, Parameters__c FROM Message__c WHERE Id IN ' + commaDelimitedIds;
        return Database.getQueryLocator(queryString);
    }
    
    /**
     * Prepares data for processing at the start of a nominated sequence by wrapping the pointer to the data (an id) in a
     * Message object. This Message instance is saved to the database and the Broker is immeadiately
     * invoked if it is not already running.
     *
     * @param sequenceName Name of the sequence the data is destined for.
     * @param dataId    Id of some record that the sequence will operate on.
     */
    static global Id enqueue(String sequenceName, Id dataId) {
        if (!SObjectType.Message__c.Createable) throw new Broker.CrudException('!SObjectType.Message__c.Createable'); 
         
        Map<String,Object> injectedParameters = new Map<String,Object> {
            'eda_SequenceName' => sequenceName,
            'Id' => dataId
        };
        
        return enqueue(injectedParameters);  
    }   

    /**
     * Prepares data (represented a parameters collection) for processing.
     * 
     * The parameters collection should at minimum contain 
     *  - an object Id ("Id")
     *  - a sequence name ("eda_SequenceName")
     * Failure to provide these parameters in the parameters collection will throw an EngineException
     * 
     * The parameters collection is converted to a Message object. This Message instance is saved 
     * to the database and the Broker is immeadiately invoked if it is not already running.
     *
     * @param  injectedParameters a parametrised description of the message data.
     */
    static public Id enqueue(Map<String,Object> injectedParameters) {
        if (!SObjectType.Message__c.Createable) throw new Broker.CrudException('!SObjectType.Message__c.Createable');    
        
        
        // validate params are supplied:
        if (injectedParameters == null) {
            throw new EngineException('Cannot supply a null parameters collection to Broker.enqueue(parameters)');
        }
        
        // validate minimum expected params are supplied:
        List<String> missingParameters = new List<String>();
        Set<String> expectedParameters = new Set<String>{
            'eda_SequenceName',
            'Id'     
        };
        for (String expectedParameter : expectedParameters) {
            if(!injectedParameters.keySet().contains(expectedParameter)) 
                missingParameters.add(expectedParameter);   
        }
        if (missingParameters.size() > 0) {
            throw new EngineException(
                'The following mandatory parameters were not supplied to Broker.enqueue() [' +
                String.join(missingParameters,',') + 
                ']'
            );
        }

        Map<String,Object> parameters = new Map<String,Object> {
            'eda_EntryPointGuid' => getEntryPointGuid(18),
            'eda_Position' => 0
        };
      
        // append parameters
           for (String injectedParameter : injectedParameters.keySet()) {
            parameters.put(injectedParameter,injectedParameters.get(injectedParameter));        
        }

        Broker instance = impl();
                
        //create the message destined for the 0th step of the chain
        Message__c message = new Message__c(Parameters__c = Json.serializePretty(parameters));
        
        //fetch the custom setting or create an empty one
        BrokerSettings__c setting = BrokerSettings__c.getOrgDefaults();
        if (setting == null) setting = new BrokerSettings__c();
        
        if (setting.IsPaused__c) {
            //system is paused
            //Why aren't these Messages resolved?
            //Because their pointers would be a misrepresentation of their destination
            //if the system had been rearranged during the time it was paused.
            message.Status__c = 'Queued';
        } else {
            //system is running
            message.Status__c = 'Buffered';
            instance.resolve(new List<Message__c>{message}); //RESOLVE
        }
        
        insert message;
        Broker.process();
        return message.Id;
    }
    
    /**
     * //TODO
     * //If we are scheduled, use the default batch broker which doesn't need a session id (unlike futurebroker)
     * //if (System.isScheduled()) settings.BrokerClassName__c = BatchBrokerImplementation.class.getName();
     */
    static public void process() {
        Broker impl = impl();
        if (!impl.isAlreadyRunning()) impl.restartIfWorkPending();
    }
    
    /**
     * Prepares Blob data for processing at the start of a nominated sequence
     * by wrapping the pointer to the data (an id) in a Message object
     * This Persisted Data instance is saved to the database and the Broker is
     * immeadiately invoked threreafter
     *
     * @param sequenceName Name of the sequence the data is destined for.
     * @param dataId    Blob representation of the data the sequence will operate on.
     */
    static public Id enqueue(String sequenceName, Blob data) {
        if (!SObjectType.Document.Createable) throw new Broker.CrudException('!SObjectType.Document.Createable');
            
        //prepare a very generic container
        Document document = new Document(
            Name = String.valueOf(Datetime.now().getTime()),
            Body = data,
            FolderId = UserInfo.getUserId(),
            ContentType = 'text/plain',
            Type = 'txt'
        );
        
        //store this data away and enqueue
        insert document;
        return enqueue(sequenceName, document.Id);
    }
    
    /**
     * Sets many Messages statuses to 'Started' and writes them away.
     */
    virtual global List<Database.SaveResult> mark(List<Message__c> messages) {
        try {
            if (!SObjectType.Message__c.Fields.Status__c.Updateable) throw new Broker.FlsException('!SObjectType.Message__c.Fields.Status__c.Updateable');   
            for (Message__c message : messages) message.Status__c = 'Started';
            return Database.update(messages);
        } catch (Exception e) {
            throw new EngineException('Mark failure:\n' + e.getMessage());
        }
    }
    
    /**
     * Resolves and invokes the toStringable Object for one input, handing back an in-memory collection of outputs
     *
     * @param  inputMessages Messages whose status should be Started
     * @return               Many Messages whose status should be Buffered
     */
    virtual global List<Message__c> execute(List<Message__c> inputMessages) {
        //empty inputs, empty outputs
        if (inputMessages.isEmpty()) return new List<Message__c>();
        
        Message__c message = inputMessages[0]; //TODO chunking
        List<Map<String,Object>> results;
        Map<String,Object> parameters;
        Type reflector;
        Object process;
        
        //OUR FUCKUPS ( before invocation )
        try {
            parameters = (Map<String,Object>)Json.deserializeUntyped(message.Parameters__c);
    
            Step__c step = [
                SELECT Process__c, ConfigurationId__c, Process__r.Name, Process__r.FullyQualifiedClassName__c
                FROM Step__c
                WHERE Id = :message.Step__c
            ];
        
            parameters.put('eda_ConfigObjectId', Step.ConfigurationId__c);
        
            //instantiate processable instance
            reflector = Type.forName(Step.Process__r.FullyQualifiedClassName__c);
            if (reflector == null) throw new EngineException('Reflector was null! ' + step.Process__r);
        } catch (Exception e) {
            if (e instanceof System.JsonException) {
                throw new EngineException('Could not deserialize json, eg malformed parameters:\n' + e.getMessage());
            } else if (e instanceof System.NullPointerException) {
                throw new EngineException('Position null, eg key missing from parameters, or Type null eg class missing:\n' + e.getMessage());
            } else if (e instanceof System.QueryException) {
                throw new EngineException('Step unqueryable, eg bad sequence name, position, missing terminate:\n' + e.getMessage());
            } else if (e instanceof System.TypeException) {
                throw new EngineException('Could not cast Process.Plugin, eg interface unimplemented on process class:\n' + e.getMessage()); //#547 this will never happen... there is no longer an interface and ALL implementors are Object anyway
            } else {
                throw new EngineException('Other pre-invocation exception:\n' + e.getMessage());
            }
        }
        
        //THEIR FUCKUPS (invocation)
        try {
            //save important message properties (such as stackDepth) so that process authors 
            
            //save important message properties (such as stackDepth) so that process authors 
            //cannot pervert them  
            //TODO : requires a more generic approach not specific to just the eda_StackDepth
            //       property
            Integer stackDepth = getStackDepth(parameters, stackDepthThreshold);
            //call invoke the processable instance
            results = Broker.invoke(reflector, parameters);
            //write back save important message properties 
            //TODO : requires a more generic approach to write back the "eda_" properties to 
            //       the parameters collections in results
            this.applyStackDepth(results, stackDepth);
        } catch (Exception e) {
            throw new EngineException('Execute failure in user process:\n' + e.getMessage());
        }
        
        //gate processing support method
        this.gateHelper(parameters, results);
        
        //wrap up results into Messages
        List<Message__c> messages = new List<Message__c>();
        for (Map<String,Object> n : results) {
            messages.add(new Message__c(
                Parameters__c = Json.serializePretty(n),
                Status__c = 'Buffered'
            ));
        }
        return messages;
    }

    /**
     * Increments parameters then resolves their destined Sequence, Step, and Process.
     *
     * 1. hydrate the parameters from message
     * 2. increments the position by one, ready to resolve the next step in the sequence
     * 3. modify the parameters to reflect the new position
     * 4A. resolve the step from the parameters
     * 4B. resolve the the process (ie the process referenced by 4A's step)
     * 5. only then can we correctly write to database with 4A (stepId) and 3 (parameters with the incremented position)
     */
    virtual global void resolve(List<Message__c> messages) {
        try {
            //assemble a map of next-step keys to messages
            Map<String,Message__c> key2data = new Map<String,Message__c>();
            for (Message__c message : messages) {
                Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(message.Parameters__c);
                String sequenceName = (String)parameters.get('eda_SequenceName');
                Decimal position = (Decimal)parameters.get('eda_Position') + 1; //care
                String key = sequenceName + '#' + position;
                key2data.put(key, message);
                
                //increment the position and put it back while we're at it
                parameters.put('eda_Position', position);
                message.Parameters__c = Json.serializePretty(parameters);
            }
            
            //resolve the next steps and processes
            List<Step__c> steps = [
                SELECT Id, Process__r.Id, Sequence__r.Id, SequenceNameAndPosition__c
                FROM Step__c
                WHERE SequenceNameAndPosition__c IN :key2data.keySet()
            ];
            
            //assemble a map of next-step keys to steps
            Map<String,Step__c> key2step = new Map<String,Step__c>();
            for (Step__c step : steps) key2step.put(step.SequenceNameAndPosition__c, step);
            
            //now put the resolved sequence/step/process on each message
            for (Message__c message : messages) {
            //OUR FUCKUPS ( after invocation )
                Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(message.Parameters__c);
                String sequenceName = (String)parameters.get('eda_SequenceName');
                Decimal position = (Decimal)parameters.get('eda_Position'); //care
                String key = sequenceName + '#' + position;
                
                Step__c step = key2step.get(key);
                message.Sequence__c = step.Sequence__r.Id;
                message.Process__c = step.Process__r.Id;
                message.Step__c = step.Id;
            }
        } catch (Exception e) {
            throw new EngineException('Resolve failure, check sequence config:\n' + e.getMessage());
        }
    }
    
    virtual global List<Database.UpsertResult> persist(List<Message__c> inputMessages, List<Message__c> outputMessages) {
        try {
            for (Message__c message : inputMessages) {
                //designate all input messages as finished
                message.Status__c = 'Completed';
            }
            
            //transact both inputs and outputs in one fell swoop
            List<Message__c> messages = new List<Message__c>();
            messages.addAll(inputMessages);
            messages.addAll(outputMessages);
            return Database.upsert(messages, true); //all or none
        } catch (Exception e) {
            throw new EngineException('Persist failure:\n' + e.getMessage());
        }
    }
    
    public void surfaceException(Exception e, Id messageId) {
        if (!SObjectType.Note.Createable) throw new Broker.CrudException('!SObjectType.Note.Createable');
        if (!SObjectType.Message__c.Fields.Exception__c.Updateable) throw new Broker.FlsException('!SObjectType.Message__c.Fields.Exception__c.Updateable');   

        Map<String,Object> serializedException = new Map<String,Object>();
        serializedException.put('cause', e.getCause());
        serializedException.put('lineNumber', e.getLineNumber());
        serializedException.put('message', e.getMessage());
        serializedException.put('stackTraceString', e.getStackTraceString());
        serializedException.put('typeName', e.getTypeName());
        
        //log exception summary on parameters
        Database.update(new Message__c(
            Id = messageId,
            Exception__c = e.getMessage().left(255)
        ));
        
        //log exception details over 255 bytes using note object
        insert new Note(
            ParentId = messageId,
            Title = e.getMessage().left(80),
            Body = Json.serializePretty(serializedException).left(32000)
        );
    }

     /**
     * Context:
     * A message can pass through a limited number of steps. This "limit" is a fairly high arbitrary threshold.
     * The intent is to prevent a never ending self referencing loop (we cannot control what the system configurators
     * configure). A self referencing loop would eventually ring alarm bells with the Salesforce police with the
     * possibility of the Munger being blacklisted
     * An exception is thrown if the stackDepth threshold is reached
     *
     * We cannot simply increment  eda_StackDepth BEFORE calling invoke as a process writer could fuck with this parameter
     * Instead we read and increment eda_StackDepth BEFORE calling invoke using getStackDepth()
     * and assign to an Integer stackDepth variable
     * We use applyStackDepth()  to apply the incremented stackDepth variable to the eda_StackDepth parameter of
     * all messages returned from invoke()
     */
    @TestVisible List<Map<String,Object>> applyStackDepth(List<Map<String,Object>> results, Integer stackDepth) {
        for (Map<String,Object> result : results) {
            result.put('eda_StackDepth',stackDepth);
        }
        return results;
    }

    /**
     * See applyStackDepth() method for context and details.
     */
    @TestVisible static private Integer getStackDepth(Map<String,Object> parameters, Integer threshold) {
        Integer stackDepth = (parameters.get('eda_StackDepth') == null) ? 0 : (Integer) parameters.get('eda_StackDepth');
        stackDepth++;
        if (stackDepth > threshold) {
            throw new EngineException('Maximum Stack Depth exceeded - to resolve, manually set eda_StackDepth on parameters to 0');
        }
        return stackDepth;
    }
    
    
    /**
     * The Mark helper logic is for the Gate process; it determines when a split occurs, and writes away the number of
     * splitted parameter sets so that a future Gate process can know exactly how many parameter sets form a Gate Group.
     *
     * If markCount isn't null, then the preceding process was a Mark; increment THEN put that value on parameters.
     * If markCount equates to two, then the preceding process was a splitter; write the count of split parameter sets.
     */
    @TestVisible private void gateHelper(Map<String,Object> parameters, List<Map<String,Object>> outputs) {
        Decimal markCount = (Decimal)parameters.get('eda_MarkCount');
        
        if (null == markCount) {
            //nothing to do, mark process has not tainted the input
            return;
        }
        
        if (outputs.isEmpty()) {
            //nothing to do, split process did not return any outputs, tidy up the gate group
            //Database.delete(new List<Id>{(Id)parameters.get('eda_GateGroupId')});
            return;
        }
        
        markCount++;
        
        for (Map<String,Object> output : outputs) {
            //write markCount onto every output
            output.put('eda_MarkCount', markCount);
        }
        
        if (2 == markCount) {
            //write outputSize onto every output
            for (Map<String,Object> output : outputs) output.put('eda_Count', outputs.size());
        }
    }
    
    global void restartIfWorkPending() {
        Integer worksPending = [
            SELECT COUNT()
            FROM Message__c
            WHERE Status__c = 'Buffered'
            OR Status__c = 'Rebuffered'
        ];
        
        if (worksPending > 0) {
            this.restartImpl();
        }
    }
    
    abstract global Boolean isAlreadyRunning();
     
    abstract global void restartImpl();
    
    @TestVisible static private String getEntryPointGuid(Integer size) {
        return EncodingUtil.convertToHex(crypto.generateAesKey(128)).substring(0, size);
    }
}