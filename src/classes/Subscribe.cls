public with sharing class Subscribe {

    public String Event;
    
    /**
     * @docs ProcessPublishSubscribe.html
     */
    public class ESB {
        public String Tag = 'Enterprise Service Bus';
        public String Name = 'Subscribe';
        public String Description = 'Listens for messages via a named Event Type.';
        public SObject StepConfig = SubscribeConfig__c.SObjectType.newSObject();
        public String Icon = 'eye';
        public String HelpUrl = new PageReference('/apex/Csh?topic=ProcessPublishSubscribe').getUrl();
        public Integer Limits = 5000; //leave half of 10,000 (Total number of records retrieved by Database.getQueryLocator)
        public String Cardinality = 'One';
    }
    
    override public String toString() {
        Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(this.Event);
        return Json.serialize(new List<Map<String,Object>>{parameters});
    }
}