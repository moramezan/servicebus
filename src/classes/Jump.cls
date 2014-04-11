public with sharing class Jump implements Process.Plugin {

    public class Meta {
        public SObject ConfigObject = JumpConfiguration__c.SObjectType.newSObject();
        public String Icon = 'arrow_switch';
        public String DocsPageUrl = Url.getSalesforceBaseUrl().toExternalForm() + Page.JumpHelp.getUrl();
    }
    
    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
        plugin.Tag = 'Event Driven Architecture';
        plugin.Name = 'Jump';
        plugin.Description = 'Permanently diverts the message to another sequence, never to return';
        return plugin;
    }
    
    public Process.PluginResult invoke(Process.PluginRequest request) {
        Map<String,Object> parameters = request.inputParameters;
        
        //get destination from configuration
        JumpConfiguration__c configuration = (JumpConfiguration__c)SalesforceObject.getById((Id)parameters.get('eda_ConfigObjectId'));
        Sequence__c sequence = (Sequence__c)SalesforceObject.getById(configuration.Sequence__c);
        
        parameters.put('eda_SequenceName', sequence.Name);
        parameters.put('eda_Position', 0);
        
        return EdaUtility.convert(new List<Map<String,Object>>{parameters});
    }

}