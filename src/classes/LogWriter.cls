public class LogWriter implements Process.Plugin {
    
    public class LogWriterException extends Exception {}
    
    public class Eda {
        public String icon = 'pencil_add';
    }
    
    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
        plugin.Name = 'LogWriter';
        plugin.Description = 'Stores the current state under a Log Entry Grouping.';
        plugin.Tag = 'Event Driven Architecture';
        return plugin;
    }
    
    
    public Process.PluginResult invoke(Process.PluginRequest pluginRequest) {
        Map<String,Object> parameters = pluginRequest.inputParameters;
        List<Map<String,Object>> parametersList = new List<Map<String,Object>>();
        
        Integer parametersOrder = (Integer)parameters.get('eda_counter');
        parametersOrder = (parametersOrder != null) ? parametersOrder : 1;
        
        String notificationId = (String)parameters.get('eda_notificationId');
        if (String.isBlank(notificationId)) {
            throw new LogWriterException('Unable to access the notification id');
        }
                
        //derive the Step
        List<Step__c> steps = [
            SELECT Id, Position__c, Sequence__c
            FROM Step__c
            WHERE Sequence__r.Name = :(String)parameters.get('eda_sequenceName')
            AND Position__c = :(Decimal) parameters.get('eda_position')
        ];
        if (steps.size() == 0) {
            throw new LogWriterException('Unable to access the Step');
        }
        Step__c step = steps[0];


    
    
        //write log entry for every log group identifier
        List<Object> collection = (List<Object>)parameters.get('eda_logGroupIds');
        if (collection != null) {
            List<Id> logGroupIds = new List<Id>();
            Set<Id> filteredLogGroupIds = (new Map<Id, LogGroup__c>([
                SELECT Id, Name
                FROM LogGroup__c
                WHERE Id IN :logGroupIds
            ])).keySet();
        
            String serializedParameters = System.Json.serializePretty(pluginRequest);
            List<LogWriterEntry__c> logWriterEntries =  new List<LogWriterEntry__c>();
            for (Id logGroupId  : filteredLogGroupIds) {
                logWriterEntries.add( new LogWriterEntry__c(
                    Step__c = step.Id,
                    Order__c   = parametersOrder,
                    LogGroup__c     = logGroupId,
                    NotificationId__c = notificationId,
                    Parameters__c    = serializedParameters
                ));
            }
            insert logWriterEntries;
        }

        parametersList.add(parameters);
        
        return Utility.convert(parametersList);
    }
}