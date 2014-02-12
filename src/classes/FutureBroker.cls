/**
 * This implementation provides snappy processing where each handler spins up new threads.
 * (Unbounded... more execution contexts spawned on demand instantaneously)
 * 
 * As opposed to the use of Batch and a QueryLocator which iterates over a limited number.
 * (Bounded... has to keep running until it finishes a set, then checks for more work)
 */
public class FutureBroker extends Broker {
    
    /**
     * The only thing we are using this PageReference for is
     * to workaround the "Callout loop not allowed" error.
     */
    public void doJob() {
        //start
        Integer fuckedLimit = 100;
        
        Integer fuckedCount = [
            SELECT COUNT()
            FROM PersistentData__c
            WHERE Status__c = 'Processing'
        ];
        
        Integer reprocessCount = [
            SELECT COUNT()
            FROM PersistentData__c
            WHERE Status__c = 'Reprocess'
        ];
        
        Integer queryLimit = Math.max(0, fuckedLimit - fuckedCount) + reprocessCount;
        
        if (queryLimit == 0) {
            //nothing to do here
            return;
        }
        
        Set<Id> persistentDataIds = new Map<Id,PersistentData__c>([
            SELECT Id
            FROM PersistentData__c
            WHERE Status__c IN ('Reprocess', 'Buffer')
            ORDER BY Status__c DESC
            LIMIT 5
        ]).keySet();
        
        //MARK IN ONE EXECUTION CONTEXT
        if (!persistentDataIds.isEmpty()) {
            String command = '';
            command += 'List<Id> persistentDataIds = (Set<Id>)Json.deserialize(\'' + Json.serialize(persistentDataIds) + '\', Set<Id>.class);';
            command += 'new FutureBroker().mark(persistentDataIds);';
            Api.Client client = new Api.Client();
            client.endpoint_x = 'https://eu2.salesforce.com/services/Soap/T/29.0';
            client.executeAnonymous(command);
        }
        
        //EXECUTE (AND RESOLVE AND PERSIST) IN SEPARATE CONTEXT
        for (Id persistentDataId : persistentDataIds) {
            String command = '';
            command += 'PersistentData__c persistentData = (PersistentData__c)SalesforceObject.getById(\'' + persistentDataId + '\');'; //hydrate for execution
            command += 'List<PersistentData__c> persistentDatas = new FutureBroker().execute(persistentData);'; //EXECUTE
            command += 'new FutureBroker().resolve(persistentDatas);'; //RESOLVE
            command += 'insert persistentDatas;'; //PERSIST
            Api.Client client = new Api.Client();
            client.endpoint_x = 'https://eu2.salesforce.com/services/Soap/T/29.0';
            client.executeAnonymous(command);
        }
        
        //REQUEUE broker in a @future
        Integer persistentDatasCount = [
            SELECT COUNT()
            FROM PersistentData__c
            WHERE Status__c = 'Buffer'
            OR Status__c = 'Reprocess'
        ];
        
        if (persistentDatasCount > 0) {
            FutureBroker.start(UserInfo.getSessionId());
        }
    }
    
    /**
     * Resolves, persists and marks a single Persistent Data, then destines him for execution.
     * 
     * @param chainName Name of the chain he is destined for.
     * @param dataId    Id of some record that the chain will operate on.
     */
    override public void enqueueImpl(String chainName, Id dataId) {
        Map<String,Object> notification = new Map<String,Object> {
            'eda__chainName' => chainName,
            'eda__sequence' => 0,  
            'id' => dataId
        };

        List<PersistentData__c> persistentDatas = new List<PersistentData__c>{new PersistentData__c(
            Status__c = 'Buffer',
            Notification__c = Json.serializePretty(notification)
        )};
        
        //RESOLVE
        super.resolve(persistentDatas);
        
        //PERSIST
        insert persistentDatas;
        
        this.startImpl();
    }
    
    /**
     * Runs @future once
     */
    public override void startImpl() {
        System.Type type = FutureBroker.class;
        String namespacePrefix;
        String name;
        
        if (type.getName().contains('.')) {
            //managed (namespaceprefix.classname)
            name = type.getName().substringBefore('.');
            namespacePrefix = type.getName().substringAfter('.');
        } else {
            //unmanaged (classname)
            name = type.getName();
            namespacePrefix = '';
        }
        
        //find existing futures
        List<AsyncApexJob> existingFutures = [
            SELECT ApexClassId, JobType
            FROM AsyncApexJob
            WHERE ApexClass.NamespacePrefix = :namespacePrefix AND ApexClass.Name = :name AND MethodName = 'start'
            AND JobType = 'Future'
            AND Status IN ('Queued', 'Processing', 'Preparing')
        ];
        
        if (!existingFutures.isEmpty()) {
            //future already exists
            return;
        }
        
        FutureBroker.start(UserInfo.getSessionId());
    }
    
    @future(callout=true) static private void start(String sessionId) {
        String futureBrokerUrl = Page.FutureBroker.getUrl(); //full page name for anonymous context
        String command = 'new PageReference(\'' + futureBrokerUrl + '\').getContent();';
        
        Api.Client client = new Api.Client(sessionId);
        client.executeAnonymous(command);
    }
    
}