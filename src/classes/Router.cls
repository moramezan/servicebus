/**
 * @obfuscation
 * Formerly known as Heartbeat
 */
public class Router extends ApexClassModel.Service {
    void callout(Map<String,Object> inputEvent) {}
    
    //#575 heartbeat evades discovery
    //public class Summary {}
    
    List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
        
        //TODO do this dynamically
        Set<String> interestedSubscriberNames = new Set<String>{
            ScheduleDaily.class.getName()
        };
        
        List<Step__c> steps = [
            SELECT Id, Sequence__c, Position__c
            FROM Step__c
            WHERE ApexClassName__c IN :interestedSubscriberNames
        ];
        
        //stamp with version
        Integer version = Integer.valueOf(BrokerSetting__c.getOrgDefaults().Version__c);
        if (version == null) version = 1;
        integer position = 0;
        
        List<Map<String,Object>> outputEvents = new List<Map<String,Object>>();
        for (Step__c step : steps) outputEvents.add(new Map<String,Object>{
            'Route' => version + '#' + step.Sequence__c + '#' + position,
            'RecordId' => inputEvent.get('RecordId') //#971 this carries difference between heartbeat and test message
        });
        
        //destined for any schedule steps
        return outputEvents;
    }
    
}