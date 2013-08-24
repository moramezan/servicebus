public class Broker implements Database.Batchable<SObject> {

    public Database.QueryLocator start(Database.BatchableContext context) {
        //find some buffered work
        Map<Id, PersistentData__c> id2data = new Map<Id, PersistentData__c>([
            SELECT Id
            FROM PersistentData__c
            WHERE RecordType.Name = 'Buffer'
            LIMIT 1000
        ]);
        
        //get the right record type
        String processingId = SObjectType.PersistentData__c.RecordTypeInfosByName.get('Processing').RecordTypeId;
        
        for (PersistentData__c persistentData : id2data.values()) {
            persistentData.RecordTypeId = processingId;
        }
        
        //mark them as processing
        update id2data.values();
        
        //get list of ids
        Set<Id> ids = id2data.keySet();
        
        //hand back just the ones we have marked (WHERE AGE < APEX TIMEOUT ETC)
        return Database.getQueryLocator('SELECT Id, Notification__c FROM PersistentData__c WHERE Id IN :ids');
    }
    
    public void execute(Database.BatchableContext context, List<SObject> scope) {
        //list of one
        PersistentData__c persistentData = (PersistentData__c)scope[0];
        
        //prepare the notification (a primitive dto) from persistent data
        Map<String,Object> n = (Map<String,Object>)Json.deserialize(persistentData.Notification__c, Map<String,Object>.class);
        
        //TODO router will resolve process name from chain step
        String chainName = (String)n.get('chainName');
        Decimal sequence = (Decimal)n.get('sequence');
        ChainStep__c chainStep = [
            SELECT Id, Process__c
            FROM ChainStep__c
            WHERE Chain__r.Name = :chainName
            AND Sequence__c = :sequence
        ];
        
        Process__c process = [
            SELECT Id, ApexClass__c
            FROM Process__c
            WHERE Id = :chainStep.Process__c
        ];
        //TODO INCREMENT CHAIN STEP HERE .. lol
        
        //instantiate processable instance
        Type reflector = Type.forName(process.ApexClass__c);
        Processable processable = (Processable)reflector.newInstance();
        
        //invoke the processable instance
        List<Map<String,Object>> notifications = processable.execute(n);
        
        //buffer these notifications into Persistent Data for future processing
        String bufferId = SObjectType.PersistentData__c.RecordTypeInfosByName.get('Buffer').RecordTypeId;
        List<PersistentData__c> persistentDatas = new List<PersistentData__c>();
        for (Map<String,Object> notification : notifications) {
            persistentDatas.add(new PersistentData__c(
                Notification__c = Json.serialize(notification),
                RecordTypeId = bufferId
            ));
        }
        insert persistentDatas;
    }
    
    public void finish(Database.BatchableContext context) {
        //thanks
    }

}