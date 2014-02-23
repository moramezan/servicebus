public with sharing class Branch implements Process.Plugin {

    public class Eda {
        public SObject configurable = BranchConfiguration__c.SObjectType.newSObject();
        public String icon = 'arrow_branch';
    }
    
    public class BranchException extends Exception {}
    
    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
        plugin.Description = 'This process forks execution';
        plugin.Tag = 'Event Driven Architecture';
        plugin.Name = 'Branch';
        return plugin;
    }
    
    public Process.PluginResult invoke(Process.PluginRequest request) {
        Map<String,Object> parameters = request.inputParameters;
        
        //get step configuration
        BranchConfiguration__c configuration = [
            SELECT Id, Sequence__r.Name
            FROM BranchConfiguration__c
            WHERE Id = :(Id)parameters.get('eda_configuration')
        ];
        
        //get sequence name
        String branchTo = configuration.Sequence__r.Name;
        
        //prevent recursion
        if (branchTo == (String)parameters.get('eda_sequenceName')) {
            throw new BranchException('Not allowed to branch to own sequence!');
        }
        
        //careful: by returning 2 parameter sets, the broker may think the process was a splitter
        Map<String,Object> clone = parameters.clone();
        
        //#47: Any messages properties affecting the TERMINATE behaviour should be stripped from FLOW CONTROL
        clone.put('eda_subsequenceStepIds', null);
        clone.put('eda_sequenceName', branchTo);
        clone.put('eda_position', 0);
        
        //TODO
        //we might have an inbound document, where parallel sequences are attempting
        //to transform the same data - if the pointer was the same they would content
        //so the document is duplicated and the duplicate handed off to the sequence
        //
        //String id = (String)parameters.get('Id');
        //if (null != id && id.startsWith('015')) {
        //  Document document = [SELECT Id, Body FROM Document WHERE Id = :id];
        //  Document clone = document.clone();
        //  insert clone;
        //  event.put('Id', clone.Id);
        //}
        
        return Utility.convert(new List<Map<String,Object>>{parameters, clone});
    }
}