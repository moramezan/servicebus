/**
 * Very fundamental order:
 * 
 * Example chain:
 * TestChain #1 [Wiretap]
 * TestChain #2 [Wiretap]
 * TestChain #3 [Terminate]
 *
 * As used by a recursing broker:
 *
 * +-----------+ (CONTEXT 1 FROM USER)
 * |  ENQUEUE  |
 * +-----------+
 *
 * +-----------+ (CONTEXT 2)
 * |  RESOLVE  |
 * |  PERSIST  |
 * |  MARK     |
 * +-----------+
 *
 * +-----------+ (CONTEXT 3)
 * |  EXECUTE  | invokes [Wiretap]
 * |  RESOLVE  |
 * |  PERSIST  |
 * |  MARK     |
 * +-----------+
 *
 * +-----------+ (CONTEXT 4)
 * |  EXECUTE  | invokes [Wiretap]
 * |  RESOLVE  |
 * |  PERSIST  |
 * |  MARK     |
 * +-----------+
 *
 * +-----------+ (CONTEXT 5)
 * |  EXECUTE  | invokes [Terminate]
 * +-----------+
 *
 *
 *
 * As used by a queueing broker:
 *
 * +-----------+ (CONTEXT 1 FROM USER)
 * |  ENQUEUE  |
 * +-----------+
 *
 * +-----------+ (CONTEXT 2 batchable.start)
 * |  MARK     | we need to "dirty" these guys with PROCESSING status in case they fuck up
 * +-----------+
 *
 * +-----------+ (CONTEXT 3 batchable.execute)
 * |  EXECUTE  | invokes [Wiretap]
 * |  RESOLVE  | ensures all generated persistentdatas never
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
 */
abstract public class AbstractBroker {

    /**
     * Sets many Persistent Datas statuses to 'Processing' and writes them away.
     *
     * @param persistentDataIds Set of Persistent Data Ids to update
     */
    public void mark(Set<Id> persistentDataIds) {
        String processingId = SObjectType.PersistentData__c.RecordTypeInfosByName.get('Processing').RecordTypeId;
        
        List<PersistentData__c> persistentDatas = [SELECT Id FROM PersistentData__c WHERE Id IN :persistentDataIds];
        for (PersistentData__c persistentData : persistentDatas) {
            persistentData.RecordTypeId = processingId;
        }
        
        update persistentDatas;
    }
    
    /**
     * Resolves and invokes the Process.Plugin for one input, handing back an in-memory collection of outputs
     * 
     * @param  persistentData One Persistent Data whose status should be Processing
     * @return                Many Persistent Datas whose status should be Buffer
     */
    public List<PersistentData__c> execute(PersistentData__c persistentData) {
        Map<String,Object> notification = (Map<String,Object>)Json.deserializeUntyped(persistentData.Notification__c);

        ChainStep__c chainStep = [
            SELECT Process__c, Configuration__c, Process__r.Name, Process__r.FullyQualifiedClassName__c
            FROM ChainStep__c
            WHERE Id = :persistentData.ChainStep__c
        ];
        
        notification.put('eda__configuration', chainStep.Configuration__c);
        
        //instantiate processable instance  
        Type reflector = Type.forName(chainStep.Process__r.FullyQualifiedClassName__c);
        Process.Plugin processable = (Process.Plugin)reflector.newInstance();
        
        //call invoke the processable instance
        Process.PluginResult  results = processable.invoke(new Process.PluginRequest(notification));
        List<Map<String,Object>> notifications = Utility.convert(results);
        
        //delete successfully processed notification
        delete persistentData;
        
        //wrap each notification in a buffered persistent data  instance and 
        //add each persistent data a persistentDatas list 
        String bufferId = SObjectType.PersistentData__c.RecordTypeInfosByName.get('Buffer').RecordTypeId;
        List<PersistentData__c> persistentDatas = new List<PersistentData__c>();
        for (Map<String,Object> n : notifications) {
            persistentDatas.add(new PersistentData__c(
                Notification__c = Json.serializePretty(n),
                RecordTypeId = bufferId
            ));
        }
        
        return persistentDatas;
    }

    /**
     * Increments notifications then resolves their destined Chain, Step, and Process.
     *
     * 1. hydrate the notification from persistent data
     * 2. increments the sequence by one, ready to resolve the next step in the chain
     * 3. modify the notification properties to reflect the new sequence
     * 4A. resolve the chain step from the notification
     * 4B. resolve the the process (ie the process referenced by 4A's chainStep)
     * 5. only then can we correctly write to database with 4A (chainStepId) and 3 (notification with the incremented sequence)
     *
     * //TODO bulkify this
     */
    public void resolve(List<PersistentData__c> persistentDatas) {
        for (PersistentData__c  persistentData : persistentDatas ) {
            Map<String,Object> notification = (Map<String,Object>)Json.deserializeUntyped(persistentData.Notification__c); 
            notification.put('eda__sequence', (Decimal)notification.get('eda__sequence') + 1);
            ChainStep__c chainStep = [
                SELECT Id, Chain__r.Id, Process__r.Id
                FROM ChainStep__c
                WHERE Chain__r.Name = :(String)notification.get('eda__chainName')
                AND Sequence__c = :(Decimal)notification.get('eda__sequence')
            ];
            
            persistentData.Notification__c = Json.serializePretty(notification);
            persistentData.Process__c = chainStep.Process__r.Id;
            persistentData.ChainStep__c = chainStep.Id;
            persistentData.Chain__c = chainStep.Chain__r.Id;
        }
    }
    
    /**
     * Destines a single piece of data for a named chain.
     *
     * @param chainName Name of target Chain
     * @param dataId    Id of SObject to operate upon
     */
    abstract void enqueue(String chainName, Id dataId);

}