public class Terminate extends ApexClassModel.Process {
    void callout(Map<String,Object> inputEvent) {}
    
    /**
     * @docs ProcessTerminate.html
     */
    public class Summary {
        String Tag = 'Enterprise Service Bus';
        String Name = 'Terminate';
        String Description = 'Swallows messages at the end of this sequence.';
        String Icon = 'stop';
        String HelpUrl = new PageReference('/apex/ContextSensitiveHelp?topic=ProcessTerminate').getUrl();
        Integer Limits = 1000; //max sync limit
        String Cardinality = 'Zero';
    }
    
    List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
        
        //TODO #995 synchronous
        //probably outputs will survive!
        
        return new List<Map<String,Object>>();
    }
    
    

}