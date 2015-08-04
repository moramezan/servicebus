public with sharing class Subscribe extends ApexClassModel.BaseProcess {

    /**
     * @docs ProcessPublishSubscribe.html
     */
    public class ESB {
        public String Tag = 'Enterprise Service Bus';
        public String Name = 'Subscribe';
        public String Description = 'Listens for messages via a named Event Type.';
        public String StepConfig = SubscribeConfig__c.class.getName();
        public String Icon = 'eye';
        public String HelpUrl = new PageReference('/apex/ContextSensitiveHelp?topic=ProcessPublishSubscribe').getUrl();
        public Integer Limits = 5000; //leave half of 10,000 (Total number of records retrieved by Database.getQueryLocator)
        public String Cardinality = 'One';
    }
    
    override protected List<Map<String,Object>> execute(Map<String,Object> parameters) {
        return new List<Map<String,Object>>{parameters};
    }
}