public class SubscribeService extends ApexClassModel.Service {
    void callout(Map<String,Object> inputEvent) {}

    public class Definition extends ApexClassModel.Definition {
        String Tag = 'Services';
        String Label = 'Subscribe';
        String Description = 'Listens for named events published by other sequences.';
        String StepConfig = SubscribeStepConfig__c.class.getName();
        String Icon = 'eye';
        Integer Chunks = 200; //no soqls, no dmls
        String Cardinality = 'One';
    }
    
    List<Map<String,Object>> execute(Map<String,Object> parameters) {
        return new List<Map<String,Object>>{parameters};
    }
}