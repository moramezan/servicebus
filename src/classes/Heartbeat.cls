public with sharing class Heartbeat implements Process.Plugin {
    
    public class HeartbeatException extends Exception {}

    public class Meta {
        public String Icon = 'heart_add';
        public String DocsPageUrl = Url.getSalesforceBaseUrl().toExternalForm() + Page.HeartbeatHelp.getUrl();
    }


    public Process.PluginDescribeResult describe () {
        Process.PluginDescribeResult result = new Process.PluginDescribeResult();
        result.Description = 'Broadcasts a heartbeat message to any sequence with a heartbeat subscriber as the first step';
        result.Tag = 'System';
        result.Name = 'Heartbeat';
        return result;
    }


    public Process.PluginResult invoke(Process.PluginRequest request) {
        Map<String,Object> parameters = request.InputParameters;
        
        Boolean isHeartbeat = (Boolean)parameters.get('eda_IsHeartbeat');
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
                parametersList.add(clone);
            }
        }

        //This process should act as a Terminate - return empty list
        return EdaUtility.convert(parametersList);
    }


    static private String getISO8601(String value) {
        value  = (value.endsWith('Z')) ? value :  value+'Z';
        DateTime localDateTime = (DateTime)Json.deserialize('"' + value + '"', DateTime.class);
        return ((''+localDateTime).replace(' ','T')); // or json.serialize(stamp) but that returns (unwanted) milliseconds)
    }
}