public with sharing class Subsequence extends ProcessModel.BaseProcess {
    
    public SubsequenceConfig__c StepConfig;
    
    /**
     * @docs ProcessBranchJumpSubsequence.html
     */
    public class ESB {
        public String Tag = 'Enterprise Service Bus';
        public String Name = 'Subsequence';
        public String Description = 'Temporarily diverts the message to another sequence, then returns it to the next step afterwards.';
        public SObject StepConfig = SubsequenceConfig__c.SObjectType.newSObject();
        public String Icon = 'arrow_undo';
        public String HelpUrl = new PageReference('/apex/Csh?topic=ProcessBranchJumpSubsequence').getUrl();
        public Integer Limits = 50; //leave half of 200 (Total number of SOQL queries issued)
        public String Cardinality = 'One';
    }
    
    override protected List<Map<String,Object>> execute(Map<String,Object> parameters) {
        
        //derive the step Id
        Step__c step = [
            SELECT Id
            FROM Step__c
            WHERE Sequence__r.Name = :(String)parameters.get('__SequenceName')
            AND Position__c = :(Decimal) parameters.get('__Position')
        ];
  
        //get destination from config
        SubsequenceConfig__c config = this.StepConfig;
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