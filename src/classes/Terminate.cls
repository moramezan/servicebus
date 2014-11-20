public with sharing class Terminate {
    
    public class Meta {
        public String Tag = 'Event Driven Architecture';
        public String Name = 'Terminate';
        public String Description = 'Swallows messages at the end of this sequence.';
        public String Icon = 'stop';
        public String HelpUrl = Url.getSalesforceBaseUrl().toExternalForm() + Page.StepCsh.getUrl();
    }
    
    public String Parameters;
    
    override public String toString() {
        Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(this.Parameters);
        
        //if we got here from a subsequence, back to where you came from!
        List<Map<String,Object>> parametersList = new List<Map<String,Object>>();
        Object data = parameters.get('eda_SubsequenceStepIds');
        
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
        
        parameters.put('eda_SubsequenceStepIds', stepIds);
        parameters.put('eda_SequenceName', sequence.Name );
        parameters.put('eda_Position', step.Position__c );
        parametersList.add(parameters);

        return Json.serialize(parametersList);
    }
    
    

}