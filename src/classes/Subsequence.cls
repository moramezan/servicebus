public class Subsequence extends ApexClassModel.Service {
    void callout(Map<String,Object> inputEvent) {}
    
    static public Boolean IsRunning = false;
    
    public class Summary {
        String Tag = 'Service Bus';
        String Label = 'Synchronous Subsequence';
        String Description = 'Synchronously executes another sequence, then resumes the next step afterwards.';
        String StepConfig = SubsequenceConfig__c.class.getName();
        String Icon = 'arrow_undo';
        String HelpUrl = new PageReference('/apex/ContextSensitiveHelp?topic=ServiceBranchJumpSubsequence').getUrl();
        Integer Limits = 1; //we dont know what they will do
        String Cardinality = 'One';
    }
    
    public class SubsequenceException extends Exception {}
    
    public void traverse(Map<String,Object> inputEvent) {
        
        //route any outputs to next step
        String route = (String)inputEvent.get('Route');
        String sequence = route.substringBefore('#');
        String position = route.substringAfter('#');
        inputEvent.put('Route', sequence + '#' + (Integer.valueOf(position) + 1));
        
        Message__c message = new Message__c(
            Event__c = Json.serialize(inputEvent)
        );
        
        ApexClassModel model = new MessageModel(message).resolveApexClassModel();
        
        //invoke callouts (this WILL explode, by design)
        model.invokeCallout(inputEvent);
        
        //invoke execute
        List<Map<String,Object>> outputEvents = model.invokeExecute(inputEvent);
        
        for (Map<String,Object> outputEvent : outputEvents) {
            //recurse into each output
            this.traverse(outputEvent);
        }
    }
    
    List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
        
        //#995 help subsequence bail out
        IsRunning = true;
        
        String stepConfigId = (Id)inputEvent.get('StepConfigId');
        if (stepConfigId == null) throw new SubsequenceException('Null step config id.');

        SubsequenceConfig__c config = [
            SELECT Id, Sequence__r.Name
            FROM SubsequenceConfig__c
            WHERE Id = :stepConfigId
        ];
        
        //sorry, no callouts in subsequences
        Savepoint savepoint = Database.setSavepoint();
        
        try {
            //he has inputs but no outputs
            Map<String,Object> clone = inputEvent.clone();
            clone.put('Route', config.Sequence__r.Name + '#0');
            this.traverse(clone);
            
        } catch (Exception e) {
            //TODO catch "callouts not supported in subsequence, jump out and jump back"
            Database.rollback(savepoint);
            throw e;
        }
        
        return new List<Map<String,Object>>{inputEvent};
    }
}