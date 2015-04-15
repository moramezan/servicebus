public with sharing class Terminate extends ProcessModel.BaseProcess {
    
    /**
     * @docs ProcessTerminate.html
     */
    public class ESB {
        public String Tag = 'Enterprise Service Bus';
        public String Name = 'Terminate';
        public String Description = 'Swallows messages at the end of this sequence.';
        public String Icon = 'stop';
        public String HelpUrl = Page.StepCsh.getUrl();
        public Integer Limits = 100; //leave half of 200 (Total number of SOQL queries issued)
        public String Cardinality = 'Zero';
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
            SELECT Id, Sequence__r.Name, Position__c
            FROM Step__c
            WHERE Id = :lastId
        ];
        
        parameters.put('__SubsequenceStepIds', stepIds);
        parameters.put('__SequenceName', step.Sequence__r.Name);
        parameters.put('__Position', step.Position__c);
        parametersList.add(parameters);

        return parametersList;
    }
    
    

}