public with sharing class Subscribe {

    public class Meta {
        public String Tag = 'Event Driven Architecture';
        public String Name = 'Subscribe';
        public String Description = 'Listens for messages via a named Event Type.';
        public SObject ConfigObject = SubscribeConfiguration__c.SObjectType.newSObject();
        public String Icon = 'eye';
        public String HelpUrl = Page.SubscribeConfigurationCsh.getUrl();
    }
    
    public String Parameters;
    
    override public String toString() {
        Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(this.Parameters);
        return Json.serialize(new List<Map<String,Object>>{parameters});
    }
}