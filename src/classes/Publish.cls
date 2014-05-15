public with sharing class Publish implements Process.Plugin {
    
    public class PublishException extends Exception {}

    public class Meta {
        public SObject ConfigObject = PublishConfiguration__c.SObjectType.newSObject();
        public String Icon = 'chart_organisation';
        public String DocsPageUrl = Url.getSalesforceBaseUrl().toExternalForm() + Page.PublishHelp.getUrl();
    }
    
    public Process.PluginDescribeResult describe () {
        Process.PluginDescribeResult result = new Process.PluginDescribeResult();
        result.Description = 'Broadcasts the message to other sequences via a named Event Type';
        result.Tag = 'Event Driven Architecture';
        result.Name = 'Publish';
        return result;
    }
    
    public Process.PluginResult invoke(Process.PluginRequest request) {
        Map<String,Object> parameters = request.InputParameters;
        List<Map<String,Object>> parametersList = new List<Map<string,object>>();
        
        PublishConfiguration__c publishConfiguration = (PublishConfiguration__c)SalesforceObject.getById((Id)parameters.get('eda_ConfigObjectId'));
        
        if (null == publishConfiguration.EventType__c) {
            throw new PublishException('Publish Configuration ' + publishConfiguration.Id + ' has no Event type');
        }
        
        Map<Id,SObject> subscribeConfigurations = new Map<Id,SObject>([
            SELECT Id
            FROM SubscribeConfiguration__c
            WHERE EventType__c = :publishConfiguration.EventType__c
        ]);
        
        List<Step__c> steps = [
            SELECT Id, Sequence__r.Name, Position__c
            FROM Step__c
            WHERE ConfigurationId__c IN :subscribeConfigurations.keySet()
        ];
        
        for (Step__c step : steps) {
            Map<String,Object> clone = parameters.clone();
            //#47: Any messages properties affecting the TERMINATE behaviour should be stripped from FLOW CONTROL
            clone.put('eda_SubsequenceStepIds', null);
            clone.put('eda_Position', step.Position__c);
            clone.put('eda_SequenceName', step.Sequence__r.Name);
            parametersList.add(clone);
        }
        
        //original guy carries on... this is not a Terminate
        parametersList.add(parameters);
        
        return EdaUtility.convert(parametersList);
    }
}