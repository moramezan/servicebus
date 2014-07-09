public with sharing class Subsequence implements Process.Plugin {

    public class Meta {
        public SObject ConfigObject = SubsequenceConfiguration__c.SObjectType.newSObject();
        public String Icon = 'arrow_undo';
        public String DocsPageUrl = Url.getSalesforceBaseUrl().toExternalForm() + Page.SubsequenceHelp.getUrl();
    }
    
    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
        plugin.Description = 'Temporarily diverts the message to another sequence, then returns it to the next step afterwards.';
        plugin.Tag = 'Event Driven Architecture';
        plugin.Name = 'Subsequence';
        
        plugin.outputParameters = new List<Process.PluginDescribeResult.OutputParameter>{
            new Process.PluginDescribeResult.OutputParameter(
                'eda_SubsequenceName',
                'Marks the sequence name which the Subsequence returns to.',
                Process.PluginDescribeResult.ParameterType.STRING
            ),
            new Process.PluginDescribeResult.OutputParameter(
                'eda_SubsequencePosition',
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
            WHERE Sequence__r.Name = :(String)parameters.get('eda_SequenceName')
            AND Position__c = :(Decimal) parameters.get('eda_Position')
        ];
  
        //get destination from configuration
        SubsequenceConfiguration__c configuration = (SubsequenceConfiguration__c)SalesforceObject.getById((Id)parameters.get('eda_ConfigObjectId'));
        Sequence__c sequence = (Sequence__c)SalesforceObject.getById(configuration.Sequence__c);
        
        List<Object> stepIds = (List<Object>)parameters.get('eda_SubsequenceStepIds');
        if (stepIds == null) {
            stepIds = new List<Object>();
        }
        stepIds.add(step.Id);
        
        parameters.put('eda_SubsequenceStepIds', stepIds);
        parameters.put('eda_SequenceName', sequence.Name);
        parameters.put('eda_Position', 0);
        
        return EdaUtility.convert(new List<Map<String,Object>>{parameters});
    }
}