public with sharing class Terminate implements Process.Plugin {
    
    public class Meta {
        public String Icon = 'stop';
        public String DocsPageUrl = Url.getSalesforceBaseUrl().toExternalForm() + Page.TerminateHelp.getUrl();
    }
    
    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
        plugin.Description = 'Swallows messages at the end of this sequence.';
        plugin.Tag = 'Event Driven Architecture';
        plugin.Name = 'Terminate';
        return plugin;
    }
    
    public Process.PluginResult invoke(Process.PluginRequest request) {
        Map<String,Object> parameters = request.inputParameters;
        
        //if we got here from a subsequence, back to where you came from!
        List<Map<String,Object>> parametersList = new List<Map<String,Object>>();
        Object data = parameters.get('eda_SubsequenceStepIds');
        
        if (data == null) {
            //no subsequences
            return EdaUtility.convert(parametersList);
        }

        List<Id> stepIds = (List<Id>)System.Json.deserialize(System.Json.serialize(data), List<Id>.class);
        if (stepIds.isEmpty()) {
            //subsequences finished
            return EdaUtility.convert(parametersList);
        }
        
        //pop one subsequence off stack
        Id lastId = stepIds.remove(stepIds.size() - 1);
        Step__c step = (Step__c)SalesforceObject.getById(lastId);
        Sequence__c sequence = (Sequence__c)SalesforceObject.getById(step.Sequence__c);
        
        parameters.put('eda_SubsequenceStepIds', stepIds);
        parameters.put('eda_SequenceName', sequence.Name );
        parameters.put('eda_Position', step.Position__c );
        parametersList.add(parameters);

        return EdaUtility.convert(parametersList);
    }

}