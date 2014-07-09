public with sharing class Subscribe implements Process.Plugin {

    public class Meta {
        public SObject ConfigObject = SubscribeConfiguration__c.SObjectType.newSObject();
        public String Icon = 'eye';
        public String DocsPageUrl = Url.getSalesforceBaseUrl().toExternalForm() + Page.SubscribeHelp.getUrl();
    }
    
    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult result = new Process.PluginDescribeResult();
        result.Description = 'Listens for messages via a named Event Type.';
        result.Tag = 'Event Driven Architecture';
        result.Name = 'Subscribe';
        return result;
    }
    
    public Process.PluginResult invoke(Process.PluginRequest request) {
        return EdaUtility.convert(new List<Map<String,Object>>{request.inputParameters});
    }
}