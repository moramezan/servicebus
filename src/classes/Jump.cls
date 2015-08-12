public class Jump extends ApexClassModel.BaseProcess {

    /**
     * @docs ProcessBranchJumpSubsequence.html
     */
    public class ESB extends ApexClassModel.BaseSummary {
        String Tag = 'Enterprise Service Bus';
        String Name = 'Jump';
        String Description = 'Permanently diverts the message to another sequence, never to return.';
        String StepConfig = JumpConfig__c.class.getName();
        String Icon = 'arrow_switch';
        String HelpUrl = new PageReference('/apex/ContextSensitiveHelp?topic=ProcessBranchJumpSubsequence').getUrl();
        Integer Limits = 50; //max sync limit
        String Cardinality = 'Zero';
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