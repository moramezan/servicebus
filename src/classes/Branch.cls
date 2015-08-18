public class Branch extends ApexClassModel.BaseProcess {

    /**
     * @docs ProcessBranchJumpSubsequence.html
     */
    public class ESB extends ApexClassModel.BaseSummary {
        String StepConfig = BranchConfig__c.class.getName();
        String Icon = 'arrow_branch';
        String HelpUrl = new PageReference('/apex/ContextSensitiveHelp?topic=ProcessBranchJumpSubsequence').getUrl();
        String Tag = 'Enterprise Service Bus';
        String Name = 'Branch';
        String Description = 'Copies the message to another sequence.';
        Integer Limits = 50; //max sync limit
        String Cardinality = 'One';
    }
    
    public class BranchException extends Exception {}
    
    List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
        
        String stepConfigId = (Id)inputEvent.get('StepConfigId');
        if (stepConfigId == null) throw new BranchException('Null step config id.');
        
        BranchConfig__c config = [
            SELECT Id, Sequence__r.Name
            FROM BranchConfig__c
            WHERE Id = :stepConfigId
        ];
        
        String route = (String)inputEvent.get('Route');
        if (route == null) throw new BranchException('Null route.');
        
        Step__c step = Step__c.getValues(route);
        if (step == null) throw new BranchException('Null step.');
        
        if (step.SequenceName__c == config.Sequence__r.Name) {
            //prevent recursion
            throw new BranchException('Not allowed to branch to own sequence!');
        }
        
        Map<String,Object> outputEvent = new Map<String,Object>{
            'Sequence' => config.Sequence__r.Name
        };
        
        //original guy carries on... this does not inadvertently Terminate
        return new List<Map<String,Object>>{inputEvent, outputEvent};
        
        //TODO
        //we might have an inbound document, where parallel sequences are attempting
        //to transform the same data - if the pointer was the same they would content
        //so the document is duplicated and the duplicate handed off to the sequence
        //
        //String id = (String)parameters.get('RecordId');
        //if (null != id && id.startsWith('015')) {
        //  Document document = [SELECT Id, Body FROM Document WHERE Id = :id];
        //  Document clone = document.clone();
        //  insert clone;
        //  event.put('RecordId', clone.Id);
        //}
    }
}