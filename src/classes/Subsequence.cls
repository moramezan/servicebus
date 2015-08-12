public class Subsequence extends ApexClassModel.BaseProcess {
    
    /**
     * @docs ProcessBranchJumpSubsequence.html
     */
    public class ESB extends ApexClassModel.BaseSummary {
        public String Tag = 'Enterprise Service Bus';
        public String Name = 'Subsequence';
        public String Description = 'Temporarily diverts the message to another sequence, then returns it to the next step afterwards.';
        public String StepConfig = SubsequenceConfig__c.class.getName();
        public String Icon = 'arrow_undo';
        public String HelpUrl = new PageReference('/apex/ContextSensitiveHelp?topic=ProcessBranchJumpSubsequence').getUrl();
        public Integer Limits = 33; //max sync limit
        public String Cardinality = 'One';
    }
    
    override protected List<Map<String,Object>> execute(Map<String,Object> parameters) {
        
        //derive the step Id
        Step__c step = [
            SELECT Id
            FROM Step__c
            WHERE SequenceName__c = :(String)parameters.get('__SequenceName')
            AND Position__c = :(Integer)parameters.get('__Position')
        ];
  
        //get destination from config
        SubsequenceConfig__c config = (SubsequenceConfig__c)ApexDomain.getById((Id)parameters.get('esb__StepConfigId'));
        Sequence__c sequence = (Sequence__c)ApexDomain.getById(config.Sequence__c);
        
        List<Object> stepIds = (List<Object>)parameters.get('__SubsequenceStepIds');
        if (stepIds == null) {
            stepIds = new List<Object>();
        }
        stepIds.add(step.Id);
        
        parameters.put('__SubsequenceStepIds', stepIds);
        parameters.put('__SequenceName', sequence.Name);
        parameters.put('__Position', 0);
        
        return new List<Map<String,Object>>{parameters};
    }
}