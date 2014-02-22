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
            Map<String,Object> parameters = new Map<String,Object>{
                'eda__position' => 0,
                'eda__sequenceName' => step.Sequence__r.Name,
                'eda__heartbeat' => DateTime.now()
            };
            
            Message__c message = new Message__c(
                Status__c = 'Buffer',
                Parameters__c = Json.serializePretty(parameters)
            );
            
            messages.add(message);
        }
        
        //enqueue the message onto the buffer
        insert messages;
    }
    
}