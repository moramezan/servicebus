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
        
        //find associated chains from their steps
        List<ChainStep__c> steps = [
            SELECT Id, Chain__r.Name, Sequence__c
            FROM ChainStep__c
            WHERE ConfigurationId__c IN :scheduleConfigurations.keySet()
        ];
        
        //destine a timestamped notification for each chain step
        List<PersistentData__c> persistentDatas = new List<PersistentData__c>();
        for (ChainStep__c step : steps) {
            Map<String,Object> notification = new Map<String,Object>{
                'eda__sequence' => 0,
                'eda__chainName' => step.Chain__r.Name,
                'eda__heartbeat' => DateTime.now()
            };
            
            PersistentData__c persistentData = new PersistentData__c(
                Status__c = 'Buffer',
                Notification__c = Json.serializePretty(notification)
            );
            
            persistentDatas.add(persistentData);
        }
        
        //enqueue the notifications onto the buffer
        insert persistentDatas;
    }
    
}