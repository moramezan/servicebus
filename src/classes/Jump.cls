public with sharing class Jump extends ApexClassModel.BaseProcess {

    /**
     * @docs ProcessBranchJumpSubsequence.html
     */
    public class ESB extends ApexClassModel.BaseSummary {
        public String Tag = 'Enterprise Service Bus';
        public String Name = 'Jump';
        public String Description = 'Permanently diverts the message to another sequence, never to return.';
        public String StepConfig = JumpConfig__c.class.getName();
        public String Icon = 'arrow_switch';
        public String HelpUrl = new PageReference('/apex/ContextSensitiveHelp?topic=ProcessBranchJumpSubsequence').getUrl();
        public Integer Limits = 50; //max sync limit
        public String Cardinality = 'Zero';
    }
    
    override protected List<Map<String,Object>> execute(Map<String,Object> parameters) {
        
        //get destination from config
        JumpConfig__c config = (JumpConfig__c)ApexDomain.getById((Id)parameters.get('esb__StepConfigId'));
        Sequence__c sequence = (Sequence__c)ApexDomain.getById(config.Sequence__c);
        
        parameters.put('__SequenceName', sequence.Name);
        parameters.put('__Position', 0);
        
        return new List<Map<String,Object>>{parameters};
    }

}