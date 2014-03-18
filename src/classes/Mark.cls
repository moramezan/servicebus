public with sharing class Mark implements Process.Plugin {
    
    public class Meta {
        public String Icon = 'tag_blue';
    }
    
    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
        plugin.Description = 'Marks splitted messages with an association key. Next process must be a split.';
        plugin.Tag = 'Event Driven Architecture';
        plugin.Name = 'Mark';
        
        plugin.OutputParameters = new List<Process.PluginDescribeResult.OutputParameter>{
            new Process.PluginDescribeResult.OutputParameter(
                'eda_MarkCount',
                'The broker will increment this to detect that the next process returned multiple messages.',
                Process.PluginDescribeResult.ParameterType.INTEGER
            ),
            new Process.PluginDescribeResult.OutputParameter(
                'eda_GateGroupId',
                'The Id of the Gate Group that eventually associates all the marked notifications.',
                Process.PluginDescribeResult.ParameterType.ID
            )
        };
        
        return plugin;
    }
    
    public Process.PluginResult invoke(Process.PluginRequest request) {
        Map<String,Object> parameters = request.inputParameters;
        
        //create a grouping id for what will ultimately be gated
        GateGroup__c gateGroup = new GateGroup__C();
        insert gateGroup;
        
        //annotate this step as the marker, so the following step must be a splitter
        parameters.put('eda_MarkCount', 0);
        parameters.put('eda_GateGroupId', gateGroup.Id);
        
        return new Process.PluginResult(new Map<String,Object>{'0' => parameters});
    }
    
}