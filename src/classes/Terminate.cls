public class Terminate extends ApexClassModel.Service {
    void callout(Map<String,Object> inputEvent) {}
    
    public class Summary {
        String Tag = 'Service Bus';
        String Label = 'Terminate';
        String Description = 'Swallows messages at the end of this sequence.';
        String Icon = 'stop';
        String HelpUrl = new PageReference('/apex/ContextSensitiveHelp?topic=ServiceTerminate').getUrl();
        Integer Limits = 200; //max sync limit
        String Cardinality = 'Zero';
    }
    
    List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
        
        //TODO #995 synchronous
        //probably outputs will survive!
        
        return new List<Map<String,Object>>();
    }
    
    

}