public class TerminateService extends ApexClassModel.Service {
    
    public class Definition extends ApexClassModel.Definition {
        String Tag = 'Services';
        String Label = 'Terminate';
        String Description = 'Swallows messages at the end of this sequence.';
        String Icon = 'stop';
        Integer Chunks = 100; //no soqls, no dmls
        String Cardinality = 'Zero';
    }
    
    override public List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
        
        //TODO #995 synchronous
        //probably outputs will survive!
        
        return new List<Map<String,Object>>();
    }
    
    

}