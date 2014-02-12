/**
 * This implementation provides snappy processing where each handler spins up new threads.
 * (Unbounded... more execution contexts spawned on demand instantaneously)
 * 
 * As opposed to the use of Batch and a QueryLocator which iterates over a limited number.
 * (Bounded... has to keep running until it finishes a set, then checks for more work)
 */
public class FutureBroker extends Broker {

    /**
     * Resolves, persists and marks a single Persistent Data, then destines him for execution.
     * 
     * @param chainName Name of the chain he is destined for.
     * @param dataId    Id of some record that the chain will operate on.
     */
    override public void enqueueImpl(String chainName, Id dataId) {
        Map<String,Object> notification = new Map<String,Object> {
            'eda__notificationId' => Broker.getNotificationId(18),
            'eda__chainName' => chainName,
            'eda__sequence' => 0,  
            'id' => dataId
        };

        List<PersistentData__c> persistentDatas = new List<PersistentData__c>{new PersistentData__c(
            Status__c = 'Buffer',
            Notification__c = Json.serializePretty(notification)
        )};
        
        //RESOLVE
        //PERSIST
        resolveAndPersist(persistentDatas);
        
        //MARK
        //EXECUTE (delegate)
        markAndExecute(persistentDatas) ; 
    }
    
    public override void startImpl() {
        List<PersistentData__c> persistentDatas = [
            SELECT Id, Name
            FROM PersistentData__c
            WHERE Status__c = 'Buffer'
            OR Status__c = 'Reprocess'
        ];

        //MARK
        //EXECUTE (delegate)
        markAndExecute(persistentDatas) ;
    }
    
    @TestVisible
    private void resolveAndPersist(List<persistentData__c> persistentDatas) {
        //RESOLVE
        super.resolve(persistentDatas);
        
        //PERSIST
        insert persistentDatas; 
    } 
    
    @TestVisible
    private void markAndExecute(List<persistentData__c> persistentDatas) {
        if (persistentDatas.size() > 0) {
            //MARK
            super.mark(new Map<Id,PersistentData__c>(persistentDatas).keySet()); //update inside
            
            //EXECUTE (delegate) 
            Set<Id> persistentDataIds = new Map<Id,PersistentData__c>(persistentDatas).keySet();
            if (Test.isRunningTest()) {
                handleMarkedPersistentDatas(persistentDataIds);
            } else {
               handleMarkedPersistentDatas(persistentDataIds, UserInfo.getSessionId());
            }
        }
    }
    
    /**
    * Test Context  
    * Note : This method will cause SOQL within a loop.
    * 
    * @param persistentDataIds Set of PersistentData records whose status is marked as Processing.
    */
    private void handleMarkedPersistentDatas(Set<Id> persistentDataIds ) {
        for (Id persistentDataId : persistentDataIds) {
            handlePersistentData(persistentDataId) ;
        }
    }
    

    /**
    * Spins up the appropriate Process.Plugin and handles a single notification, then
    * resolves, persists, marks, and destines his outputs for handling in their own threads.
    *
    * NEVER CALLED. This occurs by consequence of 'viewing' the Visualforce Page 'FutureBroker'
    * This is a necessary evil, as @future alone doesn't prevent 'Callout loop not allowed'
    */
    public void handlePersistentData() {
        Id persistentDataId = ApexPages.currentPage().getParameters().get('persistentDataId');
        handlePersistentData(persistentDataId);
    }
 
    
    
    /**
    * Spins up many new threads to handle many Persistent Data marked as Processing.
    * Of course, due to the Tooling API WebServiceCallout we cannot do DML here.
    * 
    * @param persistentDataIds Set of PersistentData records whose status is marked as Processing.
    * @param sessionId         Session ID which will be used by Tooling API execute anonymous.
    */
    @future(callout=true) static private void handleMarkedPersistentDatas(Set<Id> persistentDataIds, String sessionId) {
        //destine for execution
        List<String> commands = new List<String>();
        for (Id persistentDataId : persistentDataIds) {
           commands.add(buildHandlerCommand(persistentDataId));
        }
     
        //the eval does many Page.getContent() which achieves
        //seperate execution contexts per persistent data id
        Api.Client client = new Api.Client(sessionId);
        client.executeAnonymous(String.join(commands, '\n'));
    }
   
    private void handlePersistentData(Id persistentDataId) {
        //hydrate for execution
        PersistentData__c persistentData = [
            SELECT Id, ChainStep__c, Notification__c
            FROM PersistentData__c
            WHERE Id = :persistentDataId
        ];

        //EXECUTE                                                                                                     
        List<PersistentData__c> persistentDatas = super.execute(persistentData);                                      

                                                                                      
        //RESOLVE
        //PERSIST
        resolveAndPersist( persistentDatas);
                                                                     
        //MARK
        //EXECUTE (delegate)
        markAndExecute(persistentDatas) ;
    }
    
    /**
    * Generates apex code that news up and evaluates a uniquely named page reference.
    * Note that Page.getContent is invoking handlePersistentData in order to 'render' the page.
    * 
    * PageReference pra26b0000000PUe6 = new PageReference('/apex/eda__FutureBroker');
    * pra26b0000000PUe6.getParameters().put('persistentDataId', 'a26b0000000PUe6');
    * pra26b0000000PUe6.getContent();
    * 
    * @param persistentDataId Id of the PersistentData that will be processed.
    * @return                 String of the apex code that will be evaluated.
    */
    @TestVisible
    static private String buildHandlerCommand(Id persistentDataId) {
        String command = '';
        String identifier = 'pr'  + persistentDataId;
        String futureBrokerUrl = Page.FutureBroker.getUrl(); //full page name for anonymous context
        
        command += 'PageReference ' + identifier + ' = new PageReference(\'' + futureBrokerUrl + '\');';
        command += identifier + '.getParameters().put(\'persistentDataId\', \'' + persistentDataId + '\');';
        command += identifier + '.getContent();';
        return command;
    }
}