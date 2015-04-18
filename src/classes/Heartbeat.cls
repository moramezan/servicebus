public with sharing class Heartbeat extends ProcessModel.BaseProcess {
    
    //#575 heartbeat process evades discovery
    //public class ESB {}

    public class HeartbeatException extends Exception {}

    override protected List<Map<String,Object>> execute(Map<String,Object> parameters) {
        
        String  stampAsString = (String)parameters.get('esb__EntryPointDatetime');

        List<Map<String,Object>> parametersList = new List<Map<string,object>>();
        
        try {
           stampAsString = getISO8601(stampAsString);
        } catch (Exception e)  {
            throw new HeartbeatException('Problem with getISO8601("' + stampAsString + '")', e);
        }
        
        // TODO : re-do this dynamically
        Set<String> interestedSubscriberNames = new Set<String>{
            Schedule.class.getName()
        };
        
        List<Step__c> steps = [
            SELECT Id, SequenceName__c, Position__c
            FROM Step__c
            WHERE FullyQualifiedClassName__c IN :interestedSubscriberNames
        ];
        
        for (Step__c step : steps) {
            Map<String,Object> clone = parameters.clone();
            clone.put('__Position', step.Position__c);
            clone.put('__SequenceName', step.SequenceName__c);
            clone.put('__IsHeartbeatProcess', null); //#575 so outputs don't get same crow look as input
            clone.put('__WasHeartbeatProcess', true); //#810 use WasHeartbeat to differentiate Schedule pass throughs
            parametersList.add(clone);
        }

        //This process should act as a Terminate - return empty list
        return parametersList;
    }


    static private String getISO8601(String value) {
        value  = (value.endsWith('Z')) ? value :  value+'Z';
        DateTime localDateTime = (DateTime)Json.deserialize('"' + value + '"', DateTime.class);
        return ((''+localDateTime).replace(' ','T')); // or json.serialize(stamp) but that returns (unwanted) milliseconds)
    }
}