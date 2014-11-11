public with sharing class Jump {

    public class Meta {
        public String Tag = 'Event Driven Architecture';
        public String Name = 'Jump';
        public String Description = 'Permanently diverts the message to another sequence, never to return.';
        public SObject ConfigObject = JumpConfiguration__c.SObjectType.newSObject();
        public String Icon = 'arrow_switch';
        public String DocsPageUrl = Url.getSalesforceBaseUrl().toExternalForm() + Page.JumpHelp.getUrl();
    }
    
    public String Parameters;
    
    override public String toString() {
        Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(this.Parameters);
        
        //get destination from configuration
        JumpConfiguration__c configuration = (JumpConfiguration__c)SalesforceObject.getById((Id)parameters.get('eda_ConfigObjectId'));
        Sequence__c sequence = (Sequence__c)SalesforceObject.getById(configuration.Sequence__c);
        
        parameters.put('eda_SequenceName', sequence.Name);
        parameters.put('eda_Position', 0);
        
        return Json.serialize(new List<Map<String,Object>>{parameters});
    }

}