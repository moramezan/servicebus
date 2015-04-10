public with sharing class Jump {

    public String Event;
    public JumpConfig__c StepConfig;

    /**
     * @docs ProcessBranchJumpSubsequence.html
     */
    public class ESB {
        public String Tag = 'Enterprise Service Bus';
        public String Name = 'Jump';
        public String Description = 'Permanently diverts the message to another sequence, never to return.';
        public SObject StepConfig = JumpConfig__c.SObjectType.newSObject();
        public String Icon = 'arrow_switch';
        public String HelpUrl = new PageReference('/apex/Csh?topic=ProcessBranchJumpSubsequence').getUrl();
        public Integer Limits = 100; //leave half of 200 (Total number of SOQL queries issued)
        public String Cardinality = 'Zero';
    }
    
    override public String toString() {
        Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(this.Event);
        
        //get destination from config
        JumpConfig__c config = this.StepConfig;
        Sequence__c sequence = (Sequence__c)ApexDomain.getById(config.Sequence__c);
        
        parameters.put('__SequenceName', sequence.Name);
        parameters.put('__Position', 0);
        
        return Json.serialize(new List<Map<String,Object>>{parameters});
    }

}