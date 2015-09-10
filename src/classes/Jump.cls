public class Jump extends ApexClassModel.Service {
    void callout(Map<String,Object> inputEvent) {}

    public class Summary {
        String Tag = 'Service Bus';
        String Name = 'Jump';
        String Description = 'Permanently diverts the message to another sequence, never to return.';
        String StepConfig = JumpConfig__c.class.getName();
        String Icon = 'arrow_switch';
        String HelpUrl = new PageReference('/apex/ContextSensitiveHelp?topic=ServiceBranchJumpSubsequence').getUrl();
        Integer Limits = 50; //max sync limit
        String Cardinality = 'Zero';
    }
    
    public class JumpException extends Exception {}
    
    List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
        
        Id stepConfigId = (Id)inputEvent.get('StepConfigId');
        if (stepConfigId == null) throw new JumpException('Null step config id.');
        
        JumpConfig__c config = [
            SELECT Id, Sequence__r.Name
            FROM JumpConfig__c
            WHERE Id = :stepConfigId
        ];
        
        String route = (String)inputEvent.get('Route');
        if (route == null) throw new JumpException('Null route.');
        
        Step__c step = Step__c.getValues(route);
        if (step == null) throw new JumpException('Null step.');
        
        if (step.SequenceName__c == config.Sequence__r.Name) {
            //prevent recursion
            throw new JumpException('Not allowed to jump to own sequence.');
        }
        
        Map<String,Object> outputEvent = new Map<String,Object>{
            'Route' => config.Sequence__r.Name + '#0'
        };
        
        return new List<Map<String,Object>>{outputEvent};
    }

}