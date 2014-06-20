public class LogWriter implements Process.Plugin {
    
    public class LogWriterException extends Exception {}
    
    public class Meta {
        public String Icon = 'pencil_add';
        public String DocsPageUrl = Url.getSalesforceBaseUrl().toExternalForm() + Page.LogHelp.getUrl();
    }
    
    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
        plugin.Name = 'LogWriter';
        plugin.Description = 'Stores the message parameters under a Log Group';
        plugin.Tag = 'Event Driven Architecture';
        return plugin;
    }
    
    
    public Process.PluginResult invoke(Process.PluginRequest pluginRequest) {
        if (!SObjectType.LogWriterEntry__c.Createable) throw new Broker.CrudException('!SObjectType.LogWriterEntry__c.Createable');
        
        Map<String,Object> parameters = pluginRequest.inputParameters;
        List<Map<String,Object>> parametersList = new List<Map<String,Object>>();
        
        Integer parametersOrder = (Integer)parameters.get('eda_Counter');
        parametersOrder = (parametersOrder != null) ? parametersOrder : 1;
        
        String entryPointGuid = (String)parameters.get('eda_EntryPointGuid');
        if (String.isBlank(entryPointGuid)) {
            throw new LogWriterException('Unable to access the Entry Point GUID');
        }
                
        //derive the Step
        List<Step__c> steps = [
            SELECT Id, Position__c, Sequence__c
            FROM Step__c
            WHERE Sequence__r.Name = :(String)parameters.get('eda_SequenceName')
            AND Position__c = :(Decimal) parameters.get('eda_Position')
        ];
        if (steps.size() == 0) {
            throw new LogWriterException('Unable to access the Step');
        }
        Step__c step = steps[0];
 
        //write log entry for every log group identifier
        List<Object> collection = (List<Object>)parameters.get('eda_LogGroupIds');
        
        if (collection != null) {
            List<Id> logGroupIds = new List<Id>();
            for (Object c : collection) {
                if  (c != null) {
                  logGroupIds.add((Id) c );  
                }
            }
            Set<Id> filteredLogGroupIds = (new Map<Id, LogGroup__c>([
                SELECT Id, Name
                FROM LogGroup__c
                WHERE Id IN :logGroupIds
            ])).keySet();
        
            String serializedParameters = System.Json.serializePretty(pluginRequest.inputParameters);
            List<LogWriterEntry__c> logWriterEntries =  new List<LogWriterEntry__c>();
            for (Id logGroupId  : filteredLogGroupIds) {
                logWriterEntries.add( new LogWriterEntry__c(
                    Step__c = step.Id,
                    Sequence__c = step.Sequence__c,
                    Order__c   = parametersOrder,
                    LogGroup__c     = logGroupId,
                    EntryPointGuid__c = entryPointGuid,
                    Parameters__c    = serializedParameters
                ));
            }
            insert logWriterEntries;
        }

        parametersList.add(parameters);
        
        return EdaUtility.convert(parametersList);
    }
}