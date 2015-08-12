public class Branch extends ApexClassModel.BaseProcess {

    /**
     * @docs ProcessBranchJumpSubsequence.html
     */
    public class ESB extends ApexClassModel.BaseSummary {
        public String StepConfig = BranchConfig__c.class.getName();
        public String Icon = 'arrow_branch';
        public String HelpUrl = new PageReference('/apex/ContextSensitiveHelp?topic=ProcessBranchJumpSubsequence').getUrl();
        public String Tag = 'Enterprise Service Bus';
        public String Name = 'Branch';
        public String Description = 'Copies the message to another sequence.';
        public Integer Limits = 50; //max sync limit
        public String Cardinality = 'One';
    }

    public class BranchException extends Exception {}
    
    override protected List<Map<String,Object>> execute(Map<String,Object> parameters) {

        //get step config
        BranchConfig__c config = (BranchConfig__c)ApexDomain.getById((Id)parameters.get('esb__StepConfigId'));
        Sequence__c sequence = (Sequence__c)ApexDomain.getById(config.Sequence__c);
        
        //get sequence name
        String branchTo = sequence.Name;
        
        //prevent recursion
        if (branchTo == (String)parameters.get('__SequenceName')) {
            throw new BranchException('Not allowed to branch to own sequence!');
        }
        
        //careful: by returning 2 parameter sets, the broker may think the process was a splitter
        Map<String,Object> clone = parameters.clone();
        
        //#47: Any messages properties affecting the TERMINATE behaviour should be stripped from FLOW CONTROL
        clone.put('__SubsequenceStepIds', null);
        clone.put('__SequenceName', branchTo);
        clone.put('__Position', 0);
        
        //TODO
        //we might have an inbound document, where parallel sequences are attempting
        //to transform the same data - if the pointer was the same they would content
        //so the document is duplicated and the duplicate handed off to the sequence
        //
        //String id = (String)parameters.get('esb__RecordId');
        //if (null != id && id.startsWith('015')) {
        //  Document document = [SELECT Id, Body FROM Document WHERE Id = :id];
        //  Document clone = document.clone();
        //  insert clone;
        //  event.put('esb__RecordId', clone.Id);
        //}
        
        return new List<Map<String,Object>>{parameters, clone};
    }
}