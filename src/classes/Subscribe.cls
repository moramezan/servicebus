public class Subscribe extends ApexClassModel.Process {
    void callout(Map<String,Object> inputEvent) {}

    /**
     * @docs ProcessPublishSubscribe.html
     */
    public class Summary {
        String Tag = 'Enterprise Service Bus';
        String Name = 'Subscribe';
        String Description = 'Listens for messages via a named Event Type.';
        String StepConfig = SubscribeConfig__c.class.getName();
        String Icon = 'eye';
        String HelpUrl = new PageReference('/apex/ContextSensitiveHelp?topic=ProcessPublishSubscribe').getUrl();
        Integer Limits = 100; //could be higher but lets be reasonable
        String Cardinality = 'One';
    }
    
    List<Map<String,Object>> execute(Map<String,Object> parameters) {
        return new List<Map<String,Object>>{parameters};
    }
}