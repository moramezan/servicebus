public class Subscribe extends ApexClassModel.Service {
    void callout(Map<String,Object> inputEvent) {}

    public class Summary extends ApexClassModel.Summary {
        String Tag = 'Service Bus';
        String Label = 'Subscribe';
        String Description = 'Listens for named events published by other sequences.';
        String StepConfig = SubscribeConfig__c.class.getName();
        String Icon = 'eye';
        String HelpUrl = new PageReference('/apex/ContextSensitiveHelp?topic=ServicePublishSubscribe').getUrl();
        Integer Limits = 100; //could be higher but lets be reasonable
        String Cardinality = 'One';
    }
    
    List<Map<String,Object>> execute(Map<String,Object> parameters) {
        return new List<Map<String,Object>>{parameters};
    }
}