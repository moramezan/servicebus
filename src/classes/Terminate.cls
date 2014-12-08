public with sharing class Terminate {
    
    public String Parameters;
    
    public class Meta {
        public String Tag = 'Enterprise Service Bus';
        public String Name = 'Terminate';
        public String Description = 'Swallows messages at the end of this sequence.';
        public String Icon = 'stop';
        public String HelpUrl = Page.StepCsh.getUrl();
        public Integer AllowableInvocations = 90;
    }
    
    override public String toString() {
        Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(this.Parameters);
        
        //if we got here from a subsequence, back to where you came from!
        List<Map<String,Object>> parametersList = new List<Map<String,Object>>();
        Object data = parameters.get('esb_SubsequenceStepIds');
        
        if (data == null) {
            //no subsequences
            return Json.serialize(parametersList);
        }

        List<Id> stepIds = (List<Id>)System.Json.deserialize(System.Json.serialize(data), List<Id>.class);
        if (stepIds.isEmpty()) {
            //subsequences finished
            return Json.serialize(parametersList);
        }
        
        //pop one subsequence off stack
        Id lastId = stepIds.remove(stepIds.size() - 1);
        Step__c step = (Step__c)SalesforceObject.getById(lastId);
        Sequence__c sequence = (Sequence__c)SalesforceObject.getById(step.Sequence__c);
        
        parameters.put('esb_SubsequenceStepIds', stepIds);
        parameters.put('esb_SequenceName', sequence.Name );
        parameters.put('esb_Position', step.Position__c );
        parametersList.add(parameters);

        return Json.serialize(parametersList);
    }
    
    

}