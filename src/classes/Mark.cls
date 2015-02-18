public with sharing class Mark {
    
    public String Event;
    
    /**
     * @docs ProcessMarkGate.html
     */
    public class ESB {
        public String Tag = 'Enterprise Service Bus';
        public String Name = 'Mark';
        public String Description = 'Marks the message with a correlation key, for splitting into a collection.';
        public String Icon = 'tag_blue';
        public String HelpUrl = new PageReference('/apex/Csh?topic=ProcessMarkGate').getUrl();
        public Integer Limits = 75; //leave half of 150 (Total number of DML statements issued)
        
        public Map<String,String> Outputs = new Map<String,String>{
            'esb__GateGroupId' => 'ID of the Gate Group that eventually associates all the marked messages.'
        };
    }
    
    override public String toString() {
        if (!SObjectType.GateGroup__c.Createable) throw new SalesforceObject.CrudException('!SObjectType.GateGroup__c.Createable');
        
        Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(this.Event);
        
        //create a grouping id for what will ultimately be gated
        GateGroup__c gateGroup = new GateGroup__C();
        insert gateGroup;
        
        //annotate this step as the marker, so the following step must be a splitter
        parameters.put('__MarkCount', 0);
        parameters.put('esb__GateGroupId', gateGroup.Id);
        
        return Json.serialize(new List<Map<String,Object>>{parameters});
    }
    
}