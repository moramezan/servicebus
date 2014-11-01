public with sharing class Heartbeat implements Process.Plugin {
    
    public class HeartbeatException extends Exception {}

    public class Meta {
        public String Icon = 'heart_add';
        public String DocsPageUrl = Url.getSalesforceBaseUrl().toExternalForm() + Page.HeartbeatHelp.getUrl();
    }


    public Process.PluginDescribeResult describe () {
        Process.PluginDescribeResult result = new Process.PluginDescribeResult();
        result.Description = 'Broadcasts a heartbeat message any sequence headed by a heartbeat subscriber';
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
            Set<String> interestedSubscriberNames = new Set<String>{'Schedule'}; 
            
            List<Step__c> steps = [
                SELECT Id, Sequence__r.Name, Position__c
                FROM Step__c
                WHERE Process__r.Name IN :interestedSubscriberNames
            ];
            
            for (Step__c step : steps) {
                Map<String,Object> clone = parameters.clone();
                clone.put('eda_Position', step.Position__c);
                clone.put('eda_SequenceName', step.Sequence__r.Name);
                parametersList.add(clone);
            }
        }

        //This should act as a Terminate - do not return
        //the input message
        // (ie We are 'bending' the pattern slightly   
        // because we wish to keep the sequence that contains 
        // this process as short as possible)
        return EdaUtility.convert(parametersList);
    }


    static private String getISO8601(String value) {
        value  = (value.endsWith('Z')) ? value.subStringBefore('Z') : value;
        DateTime localDateTime = (DateTime)Json.deserialize('"' + value + '"', DateTime.class);
        DateTime localDateTime2 = DateTime.newInstance(localDateTime.date(), localDateTime.time()); 
        DateTime localDateTime3 = DateTime.newInstance(localDateTime2.year(), localDateTime2.month(), localDateTime2.day(), localDateTime2.hour(), localDateTime2.minute(), localDateTime2.second());
        return localDateTime3.format( 'yyyy-MM-dd HH:mm:ss').replace(' ','T');
    }
}