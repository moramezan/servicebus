/**
 * This scheduled class allows us to come back after the Batch Apex has finished
 * and interrogate the ExtendedStatus property. Ideally we would have just done
 * that inside the finish() method, but this property is null when queried there.
 * 
 * Many messages will all get the same exception written onto them. This is
 * unfortunate, but the Batch Apex detail only shows the first exception.
 */
public without sharing class BatchBrokerExceptionHandlerSchedule implements System.Schedulable {

    private Id asyncApexJobId;
    private Set<Id> failedMessageIds;
    
    public BatchBrokerExceptionHandlerSchedule(Id asyncApexJobId, Set<Id> failedMessageIds) {
        this.asyncApexJobId = asyncApexJobId;
        this.failedMessageIds = failedMessageIds;
    }
    
    public void execute(SchedulableContext context) {
        AsyncApexJob asyncApexJob = [
            SELECT Id, ExtendedStatus
            FROM AsyncApexJob
            WHERE Id = :this.asyncApexJobId
        ];
        
        List<Message__c> failedMessages = new List<Message__c>();
        for (Id failedMessageId : this.failedMessageIds) failedMessages.add(new Message__c(
            Id = failedMessageId,
            Exception__c = asyncApexJob.ExtendedStatus
        ));
        
        update failedMessages;
    }
    
}