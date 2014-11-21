public with sharing class Subsequence {
    
    public String Parameters;
    public SObject StepConfig;
    
    public class Meta {
        public String Tag = 'Event Driven Architecture';
        public String Name = 'Subsequence';
        public String Description = 'Temporarily diverts the message to another sequence, then returns it to the next step afterwards.';
        public SObject StepConfig = SubsequenceConfig__c.SObjectType.newSObject();
        public String Icon = 'arrow_undo';
        public String HelpUrl = Page.SubsequenceConfigCsh.getUrl();
        
        public Map<String,String> Outputs = new Map<String,String>{
            'eda_SubsequenceName' => (String.class).getName(), //Marks the sequence name which the Subsequence returns to.
            'eda_SubsequencePosition' => (Integer.class).getName() //Marks the position number which the Subsequence returns to.
        };
    }
    
    override public String toString() {
        Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(this.Parameters);
        
        //derive the step Id
        Step__c step = [
            SELECT Id
            FROM Step__c
            WHERE Sequence__r.Name = :(String)parameters.get('eda_SequenceName')
            AND Position__c = :(Decimal) parameters.get('eda_Position')
        ];
  
        //get destination from config
        SubsequenceConfig__c config = (SubsequenceConfig__c)this.StepConfig;
        Sequence__c sequence = (Sequence__c)SalesforceObject.getById(config.Sequence__c);
        
        List<Object> stepIds = (List<Object>)parameters.get('eda_SubsequenceStepIds');
        if (stepIds == null) {
            stepIds = new List<Object>();
        }
        stepIds.add(step.Id);
        
        parameters.put('eda_SubsequenceStepIds', stepIds);
        parameters.put('eda_SequenceName', sequence.Name);
        parameters.put('eda_Position', 0);
        
        return Json.serialize(new List<Map<String,Object>>{parameters});
    }
}