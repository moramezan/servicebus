public with sharing class Confirm {
    
    public ConfirmConfig__c StepConfig;
    public String Parameters;
    
    public class Meta {
        public String Tag = 'Enterprise Service Bus';
        public String Name = 'Confirm';
        public String Icon = 'control_pause_blue';
        public String Description = 'Captures messages and requires them to be confirmed in order to continue.';
        public SObject StepConfig = ConfirmConfig__c.SObjectType.newSObject();
        public String HelpUrl = Page.ConfirmConfigCsh.getUrl();
    }
    
    override public String toString() {
        Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(this.Parameters);
        
        //save away (can be resumed later)
        insert new ConfirmItem__c(
            EntityId__c = (Id)parameters.get('esb__Id'),
            Parameters__c = Json.serializePretty(parameters),
            DenySequence__c = this.StepConfig.DenySequence__c,
            ConfirmConfig__c = this.StepConfig.Id
        );
        
        //swallow
        return '[]';
    }

}