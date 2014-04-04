public class MessageSet extends SalesforceObjectSet {

    public MessageSet(List<Message__c> sobjects) {
        super(sobjects);
    }
    
    override public void onAfterInsert() {
        this.startBrokerBatch(new Map<Id,SObject>(this.getSObjects()));
    }
    
    override public void onAfterUpdate(List<Sobject> olds) {
        Map<Id,Message__c> idToNew = new Map<Id,Message__c>((List<Message__c>)this.getSObjects());
        Map<Id,Message__c> idToOld = new Map<Id,Message__c>((List<Message__c>)olds) ;
        this.startBrokerBatchIfBufferOrReprocess(idToOld, idToNew);
    }
    
    @testVisible private void startBrokerBatch(Map<Id,SObject> objects) {
        AsyncApexJobs.runOne(BatchBrokerDispatcher.class, 1);  
    }
    
    @testVisible private void startBrokerBatchIfBufferOrReprocess(Map<Id,Message__c> oldIdToOldMessage, Map<Id,Message__c> newIdToNewMessage) {
        Boolean processing2bufferOrReprocess = false;
        
        for (Message__c oldData : oldIdToOldMessage.values()) {
            Message__c newData = newIdToNewMessage.get(oldData.Id);
            if (
                oldData.Status__c == 'Processing' && newData.Status__c == 'Buffer'
                ||
                oldData.Status__c == 'Processing' && newData.Status__c == 'Reprocess'
                ||
                oldData.Status__c == 'Buffer' && newData.Status__c == 'Reprocess'
            ) {
                //if any message changed from 'Processing' to 'Buffer',    let's start the munger
                //if any message changed from 'Processing' to 'Reprocess', let's start the munger
                //if any message changed from 'Buffer'     to 'Reprocess', let's start the munger
                processing2bufferOrReprocess = true;
                break;
            }
        }

        if (processing2bufferOrReprocess) AsyncApexJobs.runOne(BatchBrokerDispatcher.class, 1);   
    }
    
}