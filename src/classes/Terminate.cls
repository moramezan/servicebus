public class Terminate extends ApexClassModel.BaseProcess {
    
    /**
     * @docs ProcessTerminate.html
     */
    public class ESB extends ApexClassModel.BaseSummary {
        String Tag = 'Enterprise Service Bus';
        String Name = 'Terminate';
        String Description = 'Swallows messages at the end of this sequence.';
        String Icon = 'stop';
        String HelpUrl = new PageReference('/apex/ContextSensitiveHelp?topic=ProcessTerminate').getUrl();
        Integer Limits = 100; //max sync limit
        String Cardinality = 'Zero';
    }
    
    override protected List<Map<String,Object>> execute(Map<String,Object> parameters) {
        
        //if we got here from a subsequence, back to where you came from!
        List<Map<String,Object>> parametersList = new List<Map<String,Object>>();
        Object data = parameters.get('__SubsequenceStepIds');
        
        if (data == null) {
            //no subsequences
            return parametersList;
        }

        List<Id> stepIds = (List<Id>)System.Json.deserialize(System.Json.serialize(data), List<Id>.class);
        if (stepIds.isEmpty()) {
            //subsequences finished
            return parametersList;
        }
        
        //pop one subsequence off stack
        Id lastId = stepIds.remove(stepIds.size() - 1);
        Step__c step = [
            SELECT Id, SequenceName__c, Position__c
            FROM Step__c
            WHERE Id = :lastId
        ];
        
        parameters.put('__SubsequenceStepIds', stepIds);
        parameters.put('__SequenceName', step.SequenceName__c);
        parameters.put('__Position', step.Position__c.intValue());
        parametersList.add(parameters);

        return parametersList;
    }
    
    

}