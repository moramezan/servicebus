public with sharing class Schedule implements Process.Plugin {
    
    public class Eda {
        public String icon = 'clock';
    }
    
    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
        plugin.Tag = 'Event Driven Architecture';
        plugin.Description = 'Fires this chain at controlled intervals {"eda__configurable":"' + Schema.SObjectType.ScheduleConfiguration__c.Name + '"}';
        plugin.Name = 'Schedule';
        return plugin;
    }
    
    public Process.PluginResult invoke(Process.PluginRequest request) {
        Map<String,Object> notification = request.inputParameters;
        List<Map<String,Object>> notifications = new List<Map<String,Object>>();
        
        
        
        return Utility.convert(notifications);
    }
    
}