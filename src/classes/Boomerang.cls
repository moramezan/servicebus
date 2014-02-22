public with sharing class Boomerang implements Process.Plugin {

    public class Eda {
        public SObject configurable = BoomerangConfiguration__c.SObjectType.newSObject();
        public String icon = 'arrow_undo';
    }
    
    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
        plugin.Description = 'Boomerang process perverts execution.';
        plugin.Tag = 'Event Driven Architecture';
        plugin.Name = 'Boomerang';
        
        plugin.outputParameters = new List<Process.PluginDescribeResult.OutputParameter>{
            new Process.PluginDescribeResult.OutputParameter(
                'eda__boomerangSequenceName',
                'Marks the sequence name which the Boomerang returns to.',
                Process.PluginDescribeResult.ParameterType.STRING
            ),
            new Process.PluginDescribeResult.OutputParameter(
                'eda__boomerangPosition',
                'Marks the position number which the Boomerang returns to.',
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
            WHERE Sequence__r.Name = :(String)parameters.get('eda__sequenceName')
            AND Position__c = :(Decimal) parameters.get('eda__position')
        ];
  
        //get destination from configuration
        BoomerangConfiguration__c configuration = [
            SELECT Id, Sequence__r.Name
            FROM BoomerangConfiguration__c
            WHERE Id = :(Id)parameters.get('eda__configuration')
        ];
        
        List<Object> stepIds = (List<Object>)parameters.get('eda__boomerangStepIds');
        if (stepIds == null) {
            stepIds = new List<Object>();
        }
        stepIds.add(step.Id);
        
        parameters.put('eda__boomerangStepIds', stepIds);
        parameters.put('eda__sequenceName', configuration.Sequence__r.Name);
        parameters.put('eda__position', 0);
        
        return Utility.convert(new List<Map<String,Object>>{parameters});
    }
}