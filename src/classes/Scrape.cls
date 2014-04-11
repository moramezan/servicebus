public class Scrape implements Process.Plugin {
    
    public class Meta {
        public SObject ConfigObject = ScrapeConfiguration__c.SObjectType.newSObject();
        public String Icon = 'html';
        public String DocsPageUrl = Url.getSalesforceBaseUrl().toExternalForm() + Page.ScrapeHelp.getUrl();
    }
    
    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
        plugin.Name = 'Scrape';
        plugin.Description = 'Downloads a webpage, saves it as an Attachment and appends the Id to the message';
        plugin.Tag = 'Sample Processes';
        return plugin;
    }
    
    public Process.PluginResult invoke(Process.PluginRequest pluginRequest) {
        Map<String,Object> parameters = pluginRequest.inputParameters;
        
        ScrapeConfiguration__c configuration = (ScrapeConfiguration__c)SalesforceObject.getById((Id)parameters.get('eda_ConfigObjectId'));
        
        HttpRequest request = new HttpRequest();
        request.setMethod('GET');
        request.setEndpoint(configuration.Endpoint__c);
        
        HttpResponse response = new Http().send(request);
        
        Attachment attachment = new Attachment(
            Name = 'Scrape',
            Body = response.getBodyAsBlob(),
            ParentId = configuration.Id,
            ContentType = response.getHeader('Content-Type')
        );
        
        insert attachment;
        parameters.put('Id', attachment.Id);
        
        List<Map<String,Object>> parametersList = new List<Map<String,Object>>{parameters};
        return EdaUtility.convert(parametersList);
    }
}