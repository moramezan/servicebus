public class Scrape implements Process.Plugin {
    
    public class Eda {
        public SObject configurable = ScrapeConfiguration__c.SObjectType.newSObject();
        public String icon = 'html';
    }
    
    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
        plugin.Name = 'Scrape';
        plugin.Description = 'Does an HTTP GET and forwards the result as an Attachment Id';
        plugin.Tag = 'Event Driven Architecture';
        return plugin;
    }
    
    public Process.PluginResult invoke(Process.PluginRequest pluginRequest) {
        Map<String,Object> notification = pluginRequest.inputParameters;
        
        ScrapeConfiguration__c configuration = [
            SELECT Id, Endpoint__c
            FROM ScrapeConfiguration__c
            WHERE Id = :(Id)notification.get('eda__configuration')
        ];
        
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
        notification.put('id', attachment.Id);
        
        List<Map<String,Object>> notifications = new List<Map<String,Object>>{notification};
        return Utility.convert(notifications);
    }
}