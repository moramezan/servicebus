public class TransactionService extends ApexClassModel.Service {
    void callout(Map<String,Object> inputEvent) {}
    
    static public Boolean IsRunning = false;
    
    public class Definition extends ApexClassModel.Definition {
        String Tag = 'Services';
        String Label = 'Transaction';
        String Description = 'Synchronously executes another sequence before emitting the event.';
        String StepConfig = TransactionStepConfig__c.class.getName();
        String Icon = 'arrow_undo';
        Integer Chunks = 1; //we dont know what their transaction contains
        String Cardinality = 'One';
        
        Map<String,String> Outputs = new Map<String,String>{
            'TerminateEvents' => 'LIST<MAP<STRING,OBJECT>> of any terminated events handled during the transaction.'
        };
    }
    
    public class ServiceException extends Exception {}
    
    public List<Map<String,Object>> TerminateEvents;
    
    public void traverse(Map<String,Object> inputEvent) {
        
        //#1147 no Message__c or persist() here! manually route any outputs to next step
        ApexClassModel.route(inputEvent);
        ApexClassModel model = ApexClassModel.fromRoute((String)inputEvent.get('Route'));
        
        //#1182 terminate transcending behaviour
        String apexTypeName = (String)inputEvent.get('Route');
        Step__c step = Step__c.getValues(apexTypeName);
        if (step != null) apexTypeName = step.ApexTypeName__c;
        if (apexTypeName == TerminateService.class.getName()) this.TerminateEvents.add(inputEvent);
        
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
        
        //#995 help transaction bail out
        IsRunning = true;
        
        String stepConfigId = (Id)inputEvent.get('StepConfigId');
        if (stepConfigId == null) throw new ServiceException('Null step config id.');
        
        TransactionStepConfig__c config;
        List<TransactionStepConfig__c> transactionStepConfigs = TransactionStepConfig__c.getAll().values(); //fetch without using soql
        for (TransactionStepConfig__c transactionStepConfig : transactionStepConfigs) if (transactionStepConfig.Id == stepConfigId) config = transactionStepConfig;
        
        //#1147 no persist happening here, gotta do our own routing!
        String route = (String)inputEvent.get('Route');
        Integer version = Integer.valueOf(route.substringBefore('#'));
        Integer position = 0;
        
        //he has inputs but no outputs
        Map<String,Object> clone = inputEvent.clone();
        Map<String,Object> outputEvent = inputEvent.clone();
        clone.put('Route', version + '#' + config.Sequence__c + '#' + position);
        
        this.TerminateEvents = new List<Map<String,Object>>();
        this.traverse(clone);
        outputEvent.put('TerminateEvents', this.TerminateEvents);
        
        return new List<Map<String,Object>>{outputEvent};
    }
}