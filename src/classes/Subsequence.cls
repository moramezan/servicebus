public with sharing class Subsequence implements Process.Plugin {

    public class Eda {
        public SObject configurable = SubsequenceConfiguration__c.SObjectType.newSObject();
        public String icon = 'arrow_undo';
    }
    
    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
        plugin.Description = 'Subsequence process perverts execution.';
        plugin.Tag = 'Event Driven Architecture';
        plugin.Name = 'Subsequence';
        
        plugin.outputParameters = new List<Process.PluginDescribeResult.OutputParameter>{
            new Process.PluginDescribeResult.OutputParameter(
                'eda_subsequenceName',
                'Marks the sequence name which the Subsequence returns to.',
                Process.PluginDescribeResult.ParameterType.STRING
            ),
            new Process.PluginDescribeResult.OutputParameter(
                'eda_subsequencePosition',
                'Marks the position number which the Subsequence returns to.',
                Process.PluginDescribeResult.ParameterType.INTEGER
            )
        };
        return plugin;
    }
    
    public Process.PluginResult invoke(Process.PluginRequest request) {
        Map<String,Object> parameters = request.inputParameters;
        
        //derive the step Id
        Step__c step = [
            SELECT Id
            FROM Step__c
            WHERE Sequence__r.Name = :(String)parameters.get('eda_sequenceName')
            AND Position__c = :(Decimal) parameters.get('eda_position')
        ];
  
        //get destination from configuration
        SubsequenceConfiguration__c configuration = [
            SELECT Id, Sequence__r.Name
            FROM SubsequenceConfiguration__c
            WHERE Id = :(Id)parameters.get('eda_configuration')
        ];
        
        List<Object> stepIds = (List<Object>)parameters.get('eda_subsequenceStepIds');
        if (stepIds == null) {
            stepIds = new List<Object>();
        }
        stepIds.add(step.Id);
        
        parameters.put('eda_subsequenceStepIds', stepIds);
        parameters.put('eda_sequenceName', configuration.Sequence__r.Name);
        parameters.put('eda_position', 0);
        
        return EdaUtility.convert(new List<Map<String,Object>>{parameters});
    }
}