public with sharing class Jump {

    public String Parameters;
    public SObject StepConfig;

    public class Meta {
        public String Tag = 'Event Driven Architecture';
        public String Name = 'Jump';
        public String Description = 'Permanently diverts the message to another sequence, never to return.';
        public SObject StepConfig = JumpConfig__c.SObjectType.newSObject();
        public String Icon = 'arrow_switch';
        public String HelpUrl = Page.JumpConfigCsh.getUrl();
    }
    
    override public String toString() {
        Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(this.Parameters);
        
        //get destination from config
        JumpConfig__c config = (JumpConfig__c)this.StepConfig;
        Sequence__c sequence = (Sequence__c)SalesforceObject.getById(config.Sequence__c);
        
        parameters.put('eda_SequenceName', sequence.Name);
        parameters.put('eda_Position', 0);
        
        return Json.serialize(new List<Map<String,Object>>{parameters});
    }

}