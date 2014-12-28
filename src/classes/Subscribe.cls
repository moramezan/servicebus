public with sharing class Subscribe {

    public String Parameters;
    
    public class ESB {
        public String Tag = 'Enterprise Service Bus';
        public String Name = 'Subscribe';
        public String Description = 'Listens for messages via a named Event Type.';
        public SObject StepConfig = SubscribeConfig__c.SObjectType.newSObject();
        public String Icon = 'eye';
        public String HelpUrl = Page.SubscribeConfigCsh.getUrl();
        public Integer Limits = 90;
    }
    
    override public String toString() {
        Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(this.Parameters);
        return Json.serialize(new List<Map<String,Object>>{parameters});
    }
}