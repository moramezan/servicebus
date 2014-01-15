public class PersistentDatas extends SObjects {

    public PersistentDatas(List<PersistentData__c> sobjects) {
        super(sobjects);
    }
    
    override public void onAfterInsert() {
        this.startBrokerBatch(new Map<Id,SObject>(this.sobjects));
    }
    
    override public void onAfterUpdate(List<Sobject> olds) {
        Map<Id,PersistentData__c> idToNew = new Map<Id,PersistentData__c>((List<PersistentData__c>)this.sobjects);
        Map<Id,PersistentData__c> idToOld = new Map<Id,PersistentData__c>((List<PersistentData__c>)olds) ;
        this.startBrokerBatchIfBufferOrReprocess(idToOld, idToNew);
    }
    
    @testVisible private void startBrokerBatch(Map<Id,SObject> objects) {
        AsyncApexJobs.runOne(Broker.class, 1);
    }
    
    @testVisible private void startBrokerBatchIfBufferOrReprocess(Map<Id,PersistentData__c> oldIdToOldPersistentData, Map<Id,PersistentData__c> newIdToNewPersistentData) {
        Id bufferId = SObjectType.PersistentData__c.RecordTypeInfosByName.get('Buffer').RecordTypeId;
        Id reprocessId = SObjectType.PersistentData__c.RecordTypeInfosByName.get('Reprocess').RecordTypeId;
        Id processingId = SObjectType.PersistentData__c.RecordTypeInfosByName.get('Processing').RecordTypeId;

        Boolean processing2bufferOrReprocess = false;
        
        for (PersistentData__c oldData : oldIdToOldPersistentData.values()) {
            PersistentData__c newData = newIdToNewPersistentData.get(oldData.Id);
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