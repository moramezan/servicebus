/**
 * DO NOT SCHEDULE THIS CLASS EVER
 */
public class ScheduleImplementation implements System.Schedulable {

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
        
        //destine a timestamped parameters for each step
        List<Message__c> messages = new List<Message__c>();
        for (Step__c step : steps) {
            Broker.enqueue(step.Sequence__r.Name, context.getTriggerId());
        }
    }
    
}