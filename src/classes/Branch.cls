public class Branch extends ApexClassModel.Service {
    void callout(Map<String,Object> inputEvent) {}

    public class Summary extends ApexClassModel.Summary {
        String StepConfig = BranchConfig__c.class.getName();
        String Icon = 'arrow_branch';
        String HelpUrl = new PageReference('/apex/ContextSensitiveHelp?topic=ServiceBranchJumpSubsequence').getUrl();
        String Tag = 'Service Bus';
        String Label = 'Branch';
        String Description = 'Copies the event to another sequence.';
        Integer Limits = 50; //max sync limit
        String Cardinality = 'One';
    }
    
    public class ServiceException extends Exception {}
    
    List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
        
        String stepConfigId = (Id)inputEvent.get('StepConfigId');
        if (stepConfigId == null) throw new ServiceException('Null step config id.');
        
        BranchConfig__c config = [
            SELECT Id, Sequence__c
            FROM BranchConfig__c
            WHERE Id = :stepConfigId
        ];
        
        String route = (String)inputEvent.get('Route');
        if (route == null) throw new ServiceException('Null route.');
        
        Step__c step = Step__c.getValues(route);
        if (step == null) throw new ServiceException('Null step.');
        
        if (step.Sequence__c == config.Sequence__c) {
            //prevent recursion
            throw new ServiceException('Not allowed to branch to own sequence!');
        }
        
        Integer version = Integer.valueOf(route.substringBefore('#'));
        Integer position = 0;
        
        Map<String,Object> outputEvent = new Map<String,Object>{
            'Route' => version + '#' + config.Sequence__c + '#' + position
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