public with sharing class Publish {
    
    public class PublishException extends Exception {}

    public class Meta {
        public String Tag = 'Event Driven Architecture';
        public String Name = 'Publish';
        public String Description = 'Broadcasts the message to other sequences via a named Event Type.';
        public SObject ConfigObject = PublishConfiguration__c.SObjectType.newSObject();
        public String Icon = 'chart_organisation';
        public String HelpUrl = Url.getSalesforceBaseUrl().toExternalForm() + Page.PublishConfigurationCsh.getUrl();
    }
    
    public String Parameters;
    
    override public String toString() {
        Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(this.Parameters);
        List<Map<String,Object>> parametersList = new List<Map<string,object>>();
        
        PublishConfiguration__c publishConfiguration = (PublishConfiguration__c)SalesforceObject.getById((Id)parameters.get('eda_ConfigObjectId'));
        
        if (null == publishConfiguration.EventType__c) {
            throw new PublishException('Publish Configuration ' + publishConfiguration.Id + ' has no Event type');
        }
        
        Map<Id,SObject> subscribeConfigurations = new Map<Id,SObject>([
            SELECT Id
            FROM SubscribeConfiguration__c
            WHERE EventType__c = :publishConfiguration.EventType__c
        ]);
        
        List<Step__c> steps = [
            SELECT Id, Sequence__r.Name, Position__c
            FROM Step__c
            WHERE ConfigurationId__c IN :subscribeConfigurations.keySet()
        ];
        
        for (Step__c step : steps) {
            Map<String,Object> clone = parameters.clone();
            //#47: Any messages properties affecting the TERMINATE behaviour should be stripped from FLOW CONTROL
            clone.put('eda_SubsequenceStepIds', null);
            clone.put('eda_Position', step.Position__c);
            clone.put('eda_SequenceName', step.Sequence__r.Name);
            parametersList.add(clone);
        }
        
        //original guy carries on... this is not a Terminate
        parametersList.add(parameters);
        
        return Json.serialize(parametersList);
    }
}