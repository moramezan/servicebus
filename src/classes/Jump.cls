public with sharing class Jump implements Process.Plugin {

    public class Meta {
        public SObject ConfigObject = JumpConfiguration__c.SObjectType.newSObject();
        public String Icon = 'arrow_switch';
        public String DocsPageUrl = Page.JumpConfigurationHelp.getUrl();
    }
    
    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
        plugin.Tag = 'Event Driven Architecture';
        plugin.Name = 'Jump';
        plugin.Description = 'Jumps to another Sequence and does not return';
        return plugin;
    }
    
    public Process.PluginResult invoke(Process.PluginRequest request) {
        Map<String,Object> parameters = request.inputParameters;
        
        //get destination from configuration
        JumpConfiguration__c configuration = [
            SELECT Id, Sequence__r.Name
            FROM JumpConfiguration__c
            WHERE Id = :(Id)parameters.get('eda_ConfigObjectId')
        ];
        
        parameters.put('eda_SequenceName', configuration.Sequence__r.Name);
        parameters.put('eda_Position', 0);
        
        return EdaUtility.convert(new List<Map<String,Object>>{parameters});
    }

}