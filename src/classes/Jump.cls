public with sharing class Jump implements Process.Plugin {

    public class Eda {
        public SObject configurable = JumpConfiguration__c.SObjectType.newSObject();
    }
       
    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
        plugin.Tag = 'Event Driven Architecture';
        plugin.Name = 'Jump';
        plugin.Description = 'Jumps to another Chain and does not return';
        return plugin;
    }
    
    public Process.PluginResult invoke(Process.PluginRequest request) {
        Map<String,Object> notification = request.inputParameters;
        
        //get destination from configuration
        JumpConfiguration__c configuration = [
            SELECT Id, Chain__r.Name
            FROM JumpConfiguration__c
            WHERE Id = :(Id)notification.get('eda__configurable')
        ];
        
        notification.put('eda__chainName', configuration.Chain__r.Name);
        notification.put('eda__sequence', 0);
        
        return Utility.convert(new List<Map<String,Object>>{notification});
    }

}