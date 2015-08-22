public class Router extends ApexClassModel.Process {
    void callout(Map<String,Object> inputEvent) {}
    
    //#575 heartbeat process evades discovery
    //public class Summary {}
    
    List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
        
        //TODO do this dynamically
        Set<String> interestedSubscriberNames = new Set<String>{
            Schedule.class.getName()
        };
        
        List<Step__c> steps = [
            SELECT Id, SequenceName__c, Position__c
            FROM Step__c
            WHERE ApexClassName__c IN :interestedSubscriberNames
        ];
        
        List<Map<String,Object>> outputEvents = new List<Map<String,Object>>();
        for (Step__c step : steps) outputEvents.add(new Map<String,Object>{
            'Route' => step.SequenceName__c + '#0',
            'RecordId' => inputEvent.get('RecordId') //#971 this carries difference between heartbeat and test message
        });
        
        //destined for any schedule steps
        return outputEvents;
    }
    
}