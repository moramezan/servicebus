public with sharing class Gate implements Process.Plugin {
    
    public class Eda {
        public String icon = 'arrow_join';
    }
    
    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
        plugin.Description = 'Gate process allows you to aggregate marked messages on a common grouping key.';
        plugin.Tag = 'Event Driven Architecture';
        plugin.Name = 'Gate';
        
        plugin.InputParameters = new List<Process.PluginDescribeResult.InputParameter>{
            new Process.PluginDescribeResult.InputParameter(
                'eda_gateGroupId',
                'Id of the GateGroup the marked messages should belong to.',
                Process.PluginDescribeResult.ParameterType.ID,
                false
            ),
            new Process.PluginDescribeResult.InputParameter(
                'eda_count',
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
        Map<String,Object> parameters = request.inputParameters;
        
        Id gateGroupId = (Id)parameters.get('eda_gateGroupId');
        Decimal count = (Decimal)parameters.get('eda_count');
        
        insert new GateItem__c(
            GateGroup__c = gateGroupId,
            Parameters__c = Json.serialize(parameters)
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
        
        return Utility.convert(new List<Map<String,Object>>{parameters});
    }
    
}