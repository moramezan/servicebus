public class PersistentDatas extends SObjects {
    
    override public void onAfterInsert(Map<Id,SObject> objects) {
        this.startBrokerBatch(objects);
    }
    
    override public void onAfterUpdate(Map<Id,SObject> olds, Map<Id,SObject> news) {
        this.startBrokerBatchIfBufferOrReprocess(olds, news);
    }
    
    @testVisible private void startBrokerBatch(Map<Id,SObject> objects) {
        AsyncApexJobs.runOne(Broker.class, 1);
    }
    
    @testVisible private void startBrokerBatchIfBufferOrReprocess(Map<Id,SObject> olds, Map<Id,SObject> news) {
        Id bufferId = SObjectType.PersistentData__c.RecordTypeInfosByName.get('Buffer').RecordTypeId;
        Id reprocessId = SObjectType.PersistentData__c.RecordTypeInfosByName.get('Reprocess').RecordTypeId;
        Id processingId = SObjectType.PersistentData__c.RecordTypeInfosByName.get('Processing').RecordTypeId;

        Boolean processing2bufferOrReprocess = false;
        
        for (PersistentData__c oldData : (List<PersistentData__c>)olds.values()) {
            PersistentData__c newData = ((Map<Id,PersistentData__c>)news).get(oldData.Id);
            if (
                oldData.RecordTypeId == processingId && newData.RecordTypeId == bufferId
                ||
                oldData.RecordTypeId == processingId && newData.RecordTypeId == reprocessId
                ||
                oldData.RecordTypeId == bufferId && newData.RecordTypeId == reprocessId
            ) {
                //if any persistent data changed from 'Processing' to 'Buffer',    let's start the munger
                //if any persistent data changed from 'Processing' to 'Reprocess', let's start the munger
                //if any persistent data changed from 'Buffer'     to 'Reprocess', let's start the munger
                processing2bufferOrReprocess = true;
                break;
            }
        }

        if (processing2bufferOrReprocess) AsyncApexJobs.runOne(Broker.class, 1);
    }
    
}