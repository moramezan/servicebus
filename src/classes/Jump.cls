public with sharing class Jump implements Process.Plugin {

    public class Eda {
        public SObject configurable = JumpConfiguration__c.SObjectType.newSObject();
        public String icon = 'arrow_switch';
    }
    
    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
        plugin.Tag = 'Event Driven Architecture';
        plugin.Name = 'Jump';
        plugin.Description = 'Jumps to another Chain and does not return';
        return plugin;
    }
    
    public Process.PluginResult invoke(Process.PluginRequest request) {
        Map<String,Object> parameters = request.inputParameters;
        
        //get destination from configuration
        JumpConfiguration__c configuration = [
            SELECT Id, Chain__r.Name
            FROM JumpConfiguration__c
            WHERE Id = :(Id)parameters.get('eda__configurable')
        ];
        
        parameters.put('eda__chainName', configuration.Chain__r.Name);
        parameters.put('eda__sequence', 0);
        
        return Utility.convert(new List<Map<String,Object>>{parameters});
    }

}