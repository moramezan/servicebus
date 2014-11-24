public with sharing class Branch {

    public String Parameters;
    public BranchConfig__c StepConfig;

    public class Meta {
        public SObject StepConfig = BranchConfig__c.SObjectType.newSObject();
        public String Icon = 'arrow_branch';
        public String HelpUrl = Page.BranchConfigCsh.getUrl();
        public String Tag = 'Event Driven Architecture';
        public String Name = 'Branch';
        public String Description = 'Copies the message to another sequence.';
    }

    public class BranchException extends Exception {}
    
    override public String toString() {
        Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(this.Parameters);

        //get step config
        BranchConfig__c config = this.StepConfig;
        Sequence__c sequence = (Sequence__c)SalesforceObject.getById(config.Sequence__c);
        
        //get sequence name
        String branchTo = sequence.Name;
        
        //prevent recursion
        if (branchTo == (String)parameters.get('eda_SequenceName')) {
            throw new BranchException('Not allowed to branch to own sequence!');
        }
        
        //careful: by returning 2 parameter sets, the broker may think the process was a splitter
        Map<String,Object> clone = parameters.clone();
        
        //#47: Any messages properties affecting the TERMINATE behaviour should be stripped from FLOW CONTROL
        clone.put('eda_SubsequenceStepIds', null);
        clone.put('eda_SequenceName', branchTo);
        clone.put('eda_Position', 0);
        
        //TODO
        //we might have an inbound document, where parallel sequences are attempting
        //to transform the same data - if the pointer was the same they would content
        //so the document is duplicated and the duplicate handed off to the sequence
        //
        //String id = (String)parameters.get('Id');
        //if (null != id && id.startsWith('015')) {
        //  Document document = [SELECT Id, Body FROM Document WHERE Id = :id];
        //  Document clone = document.clone();
        //  insert clone;
        //  event.put('Id', clone.Id);
        //}
        
        return Json.serialize(new List<Map<String,Object>>{parameters, clone});
    }
}