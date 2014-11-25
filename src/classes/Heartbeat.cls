public with sharing class Heartbeat {
    
    public String Parameters;

    //#575 heartbeat process evades discovery
    //public class Meta {}

    public class HeartbeatException extends Exception {}

    override public String toString() {
        Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(this.Parameters);
        
        Boolean isHeartbeat = ( parameters.get('eda_IsHeartbeat') == null) ?
            false :
            (Boolean)parameters.get('eda_IsHeartbeat');

        String  stampAsString = (String)parameters.get('eda_EventStamp');

        List<Map<String,Object>> parametersList = new List<Map<string,object>>();
        
        if (isHeartbeat) {
            try {
               stampAsString = getISO8601(stampAsString);
            } catch (Exception e)  {
                throw new HeartbeatException(e);
            }
            
            // TODO : re-do this dynamically        
            Set<String> interestedSubscriberNames = new Set<String>{
                Schedule.class.getName()
            }; 
            
            List<Step__c> steps = [
                SELECT Id, Sequence__r.Name, Position__c
                FROM Step__c
                WHERE Process__r.Name IN :interestedSubscriberNames
            ];
            
            for (Step__c step : steps) {
                Map<String,Object> clone = parameters.clone();
                clone.put('eda_Position', step.Position__c-1);
                clone.put('eda_SequenceName', step.Sequence__r.Name);
                clone.put('eda_IsHeartbeatProcess', null); //#575 so outputs don't get same crow look as input
                parametersList.add(clone);
            }
        }

        //This process should act as a Terminate - return empty list
        return Json.serialize(parametersList);
    }


    static private String getISO8601(String value) {
        value  = (value.endsWith('Z')) ? value :  value+'Z';
        DateTime localDateTime = (DateTime)Json.deserialize('"' + value + '"', DateTime.class);
        return ((''+localDateTime).replace(' ','T')); // or json.serialize(stamp) but that returns (unwanted) milliseconds)
    }
}