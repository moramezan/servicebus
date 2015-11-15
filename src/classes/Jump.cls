public class Jump extends ApexClassModel.Service {
    void callout(Map<String,Object> inputEvent) {}

    public class Summary extends ApexClassModel.Summary {
        String Tag = 'Service Bus';
        String Label = 'Jump';
        String Description = 'Diverts the event to another sequence, never to return.';
        String StepConfig = JumpConfig__c.class.getName();
        String Icon = 'arrow_switch';
        String HelpUrl = new PageReference('/apex/ContextSensitiveHelp?topic=ServiceBranchJumpSubsequence').getUrl();
        Integer Limits = 50; //max sync limit
        String Cardinality = 'Zero';
    }
    
    public class ServiceException extends Exception {}
    
    List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
        
        Id stepConfigId = (Id)inputEvent.get('StepConfigId');
        if (stepConfigId == null) throw new ServiceException('Null step config id.');
        
        JumpConfig__c config = [
            SELECT Id, Sequence__c
            FROM JumpConfig__c
            WHERE Id = :stepConfigId
        ];
        
        String route = (String)inputEvent.get('Route');
        if (route == null) throw new ServiceException('Null route.');
        
        Step__c step = Step__c.getValues(route);
        if (step == null) throw new ServiceException('Null step.');
        
        if (step.Sequence__c == config.Sequence__c) {
            //prevent recursion
            throw new ServiceException('Not allowed to jump to own sequence.');
        }
        
        Integer version = Integer.valueOf(route.substringBefore('#'));
        Integer position = 0;
        
        Map<String,Object> outputEvent = new Map<String,Object>{
            'Route' => version + '#' + config.Sequence__c + '#' + position
        };
        
        return new List<Map<String,Object>>{outputEvent};
    }

}