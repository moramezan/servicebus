public class Subsequence extends ApexClassModel.BaseProcess {
    
    /**
     * @docs ProcessBranchJumpSubsequence.html
     */
    public class ESB extends ApexClassModel.BaseSummary {
        String Tag = 'Enterprise Service Bus';
        String Name = 'Subsequence';
        String Description = 'Temporarily diverts the message to another sequence, then returns it to the next step afterwards.';
        String StepConfig = SubsequenceConfig__c.class.getName();
        String Icon = 'arrow_undo';
        String HelpUrl = new PageReference('/apex/ContextSensitiveHelp?topic=ProcessBranchJumpSubsequence').getUrl();
        Integer Limits = 33; //max sync limit
        String Cardinality = 'One';
    }
    
    public class SubsequenceException extends Exception {}
    
    List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
        
        String stepConfigId = (Id)inputEvent.get('StepConfigId');
        if (stepConfigId == null) throw new SubsequenceException('Null step config id.');
        
        SubsequenceConfig__c config = [
            SELECT Id, Sequence__r.Name
            FROM SubsequenceConfig__c
            WHERE Id = :stepConfigId
        ];
        
        String route = (String)inputEvent.get('Route');
        if (route == null) throw new SubsequenceException('Null route.');
        
        List<String> subsequenceRoutes = (List<String>)inputEvent.get('__SubsequenceRoutes');
        if (subsequenceRoutes == null) subsequenceRoutes = new List<String>();
        subsequenceRoutes.add(route);
        
        Map<String,Object> outputEvent = new Map<String,Object>{
            'Sequence' => config.Sequence__r.Name,
            '__SubsequenceRoutes' => subsequenceRoutes
        };
        
        //#994 re-use enqueue logic to do pre-routing
        List<Map<String,Object>> outputEvents = new Job(outputEvent).Events;
        
        return outputEvents;
    }
}