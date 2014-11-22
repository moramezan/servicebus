public with sharing class Mark {
    
    public String Parameters;
    
    public class Meta {
        public String Tag = 'Event Driven Architecture';
        public String Name = 'Mark';
        public String Description = 'Marks the message with a correlation key, for splitting into a collection.';
        public String Icon = 'tag_blue';
        public String HelpUrl = Page.GateGroupCsh.getUrl();
        
        public Map<String,String> Outputs = new Map<String,String>{
            'eda_MarkCount' => 'INTEGER the broker will calculate this to detect that the next process returned multiple messages.',
            'eda_GateGroupId' => 'ID of the Gate Group that eventually associates all the marked messages.'
        };
    }
    
    override public String toString() {
        if (!SObjectType.GateGroup__c.Createable) throw new Broker.CrudException('!SObjectType.GateGroup__c.Createable');
        
        Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(this.Parameters);
        
        //create a grouping id for what will ultimately be gated
        GateGroup__c gateGroup = new GateGroup__C();
        insert gateGroup;
        
        //annotate this step as the marker, so the following step must be a splitter
        parameters.put('eda_MarkCount', 0);
        parameters.put('eda_GateGroupId', gateGroup.Id);
        
        return Json.serialize(new List<Map<String,Object>>{parameters});
    }
    
}