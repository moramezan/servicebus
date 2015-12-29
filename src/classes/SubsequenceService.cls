public class SubsequenceService extends ApexClassModel.Service {
    void callout(Map<String,Object> inputEvent) {}
    
    static public Boolean IsRunning = false;
    
    public class Summary extends ApexClassModel.Summary {
        String Tag = 'Service Bus';
        String Label = 'Subsequence';
        String Description = 'Synchronously executes another sequence before emitting the event.';
        String StepConfig = SubsequenceStepConfig__c.class.getName();
        String Icon = 'arrow_undo';
        Integer Chunks = 1; //we dont know what their subsequence contains
        String Cardinality = 'One';
    }
    
    public class ServiceException extends Exception {}
    
    public void traverse(Map<String,Object> inputEvent) {
        
        //#1147 no Message__c or persist() here! manually route any outputs to next step
        ApexClassModel.route(inputEvent);
        ApexClassModel model = ApexClassModel.fromRoute((String)inputEvent.get('Route'));
        
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
        if (stepConfigId == null) throw new ServiceException('Null step config id.');
        
        SubsequenceStepConfig__c config;
        List<SubsequenceStepConfig__c> subsequenceStepConfigs = SubsequenceStepConfig__c.getAll().values(); //fetch without using soql
        for (SubsequenceStepConfig__c subsequenceStepConfig : subsequenceStepConfigs) if (subsequenceStepConfig.Id == stepConfigId) config = subsequenceStepConfig;
        
        //#1147 no persist happening here, gotta do our own routing!
        String route = (String)inputEvent.get('Route');
        Integer version = Integer.valueOf(route.substringBefore('#'));
        Integer position = 0;
        
        //he has inputs but no outputs
        Map<String,Object> clone = inputEvent.clone();
        clone.put('Route', version + '#' + config.Sequence__c + '#' + position);
        this.traverse(clone);
        
        return new List<Map<String,Object>>{inputEvent};
    }
}