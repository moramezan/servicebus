public with sharing class Disperse extends ProcessModel.BaseProcess {
    
    public DisperseConfig__c StepConfig;
    
    public class ESB {
        public String Tag = 'Enterprise Service Bus';
        public String Name = 'Disperse';
        public String Description = 'Copies the message to multiple sequences simultaneously.';
        public String Icon = 'chart_organisation';
        public String HelpUrl = Page.DisperseConfigCsh.getUrl();
        public String StepConfig = DisperseConfig__c.class.getName();
        public Integer Limits = 100; //leave half of 200 (Total number of SOQL queries issued)
    }
    
    public class DisperseException extends Exception {}
    
    override protected List<Map<String,Object>> execute(Map<String,Object> parameters) {
        
        DisperseConfig__c config = (DisperseConfig__c)Json.deserialize(Json.serialize(parameters.get('esb__StepConfig')), DisperseConfig__c.class);
        
        //find all the sequences
        List<DisperseDestination__c> destinations = [
            SELECT Id, Sequence__r.Name
            FROM DisperseDestination__c
            WHERE DisperseConfig__c = :config.Id
        ];
        
        //catch dumb configuration
        for (DisperseDestination__c destination : destinations) {
            if (destination.Sequence__r.Name == (String)parameters.get('__SequenceName')) {
                throw new DisperseException('Disperse cannot include its own Sequence as a Destination.');
            }
        }
        
        //fan out a bunch of messages
        List<Map<String,Object>> outputs = new List<Map<String,Object>>();
        for (DisperseDestination__c destination : destinations) {
            outputs.add(new Map<String,Object>{
                'esb__SequenceName' => destination.Sequence__r.Name
            });
        }
        
        return outputs;
    }

}