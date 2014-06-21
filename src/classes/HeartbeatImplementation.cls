/**
 * DO NOT SCHEDULE THIS CLASS EVER
 * http://salesforce.stackexchange.com/a/24448/320
 */
public with sharing class HeartbeatImplementation implements System.Schedulable {

    public void execute(System.SchedulableContext context) {
        //find valid schedule configurations
        Map<Id,SObject> scheduleConfigurations = new Map<Id,SObject>([
            SELECT Id
            FROM ScheduleConfiguration__c
            WHERE Frequency__c IN ('Daily', 'Weekly', 'Monthly')
        ]);
        
        //find associated sequences from their steps
        List<Step__c> steps = [
            SELECT Id, Sequence__r.Name, Position__c
            FROM Step__c
            WHERE ConfigurationId__c IN :scheduleConfigurations.keySet()
        ];
        
        //destine a heartbeat (whose crondetail carries the timestamp) for each step
        List<Message__c> messages = new List<Message__c>();
        for (Step__c step : steps) {
            Broker.enqueue(step.Sequence__r.Name, context.getTriggerId());
        }
    }
    
}