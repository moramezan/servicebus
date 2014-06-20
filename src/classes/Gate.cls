public with sharing class Gate implements Process.Plugin {
    
    public class Meta {
        public String Icon = 'arrow_join';
        public String DocsPageUrl = Url.getSalesforceBaseUrl().toExternalForm() + Page.GateHelp.getUrl();
    }
    
    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
        plugin.Description = 'Aggregates a collection of messages previously marked with a correlation key';
        plugin.Tag = 'Event Driven Architecture';
        plugin.Name = 'Gate';
        
        plugin.InputParameters = new List<Process.PluginDescribeResult.InputParameter>{
            new Process.PluginDescribeResult.InputParameter(
                'eda_GateGroupId',
                'Id of the GateGroup the marked messages should belong to.',
                Process.PluginDescribeResult.ParameterType.ID,
                false
            ),
            new Process.PluginDescribeResult.InputParameter(
                'eda_Count',
                'Number of marked messages the gate should expect.',
                Process.PluginDescribeResult.ParameterType.INTEGER,
                false
            )
        };
        
        plugin.OutputParameters = new List<Process.PluginDescribeResult.OutputParameter>{
            new Process.PluginDescribeResult.OutputParameter(
                'Id',
                'Id of the GateGroup whose members are now all present.',
                Process.PluginDescribeResult.ParameterType.ID
            )
        };
        
        return plugin;
    }
    
    public Process.PluginResult invoke(Process.PluginRequest request) {
        if (!SObjectType.GateItem__c.Createable) throw new Broker.CrudException('!SObjectType.GateItem__c.Createable');
    
        Map<String,Object> parameters = request.inputParameters;
        
        Id gateGroupId = (Id)parameters.get('eda_GateGroupId');
        Decimal count = (Decimal)parameters.get('eda_Count');
        
        insert new GateItem__c(
            GateGroup__c = gateGroupId,
            Parameters__c = Json.serializePretty(parameters)
        );
        
        List<GateItem__c> gateItems = [
            SELECT Id
            FROM GateItem__c
            WHERE GateGroup__c = :gateGroupId
        ];
        
        if (count != gateItems.size()) {
            //this is not the last item, so let's swallow
            return new Process.PluginResult(new Map<String,Object>());
        }
        
        //this is the last item, let's release
        parameters.put('Id', gateGroupId);
        parameters.remove('eda_Count');
        parameters.remove('eda_MarkCount');
        parameters.remove('eda_GateGroupId');
        
        return EdaUtility.convert(new List<Map<String,Object>>{parameters});
    }
    
}