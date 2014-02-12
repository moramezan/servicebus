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
        Map<String,Object> notification = pluginRequest.inputParameters;
        List<Map<String,Object>> notifications = new List<Map<String,Object>>();
        
        Integer notificationOrder = (Integer)notification.get('eda__counter');
        notificationOrder = (notificationOrder != null) ? notificationOrder : 1;
        
        String notificationId = (String)notification.get('eda__notificationId');
        if (String.isBlank(notificationId)) {
            throw new LogWriterException('Unable to access the notification id');
        }
                
        //derive the ChainStep
        List<ChainStep__c> chainSteps = [
            SELECT Id, Sequence__c, Chain__c
            FROM ChainStep__c
            WHERE Chain__r.Name = :(String)notification.get('eda__chainName')
            AND Sequence__c = :(Decimal) notification.get('eda__sequence')
        ];
        if (chainSteps.size() == 0) {
            throw new LogWriterException('Unable to access the Chain Step');
        }
        ChainStep__c chainStep = chainSteps[0];


    
    
        //write log entry for every log group identifier
        List<Object> collection = (List<Object>)notification.get('eda__logGroupIds'); 
        if (collection != null) {
            List<Id> logGroupIds = new List<Id>();
            Set<Id> filteredLogGroupIds = (new Map<Id, LogGroup__c>([
                SELECT Id, Name 
                FROM LogGroup__c
                WHERE Id IN :logGroupIds
            ])).keySet();
        
            String serializedNotification = System.Json.serializePretty(pluginRequest);
            List<LogWriterEntry__c> logWriterEntries =  new List<LogWriterEntry__c>();
            for (Id logGroupId  : filteredLogGroupIds) {
                logWriterEntries.add( new LogWriterEntry__c(
                    ChainStep__c = chainStep.Id, 
                    Order__c   = notificationOrder,
                    LogGroup__c     = logGroupId,
                    NotificationId__c = notificationId,
                    Notification__c    = serializedNotification
                ));
            }
            insert logWriterEntries;
        }

        notifications.add(notification);
        
        return Utility.convert(notifications);
    }
}