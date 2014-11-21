public with sharing class Wiretap {
   
    public String Parameters;
    
    public class Meta {
        public String Tag = 'Event Driven Architecture';
        public String Name = 'Wiretap';
        public String Description = 'Emails the message parameters to the user.';
        public SObject CustomSetting = WiretapSettings__c.SObjectType.newSObject();
        public String Icon = 'email';
        public String HelpUrl = Page.LogWriterEntryCsh.getUrl();
    }
    
    override public String toString() {
        Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(this.Parameters);
        
        Id userId;
        try {
            WiretapSettings__c setting = WiretapSettings__c.getInstance();
            userId = setting.UserId__c;
        } catch (Exception e) {
        }
        if (userId == null) {
            userId = UserInfo.getUserId();
        }

        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.setSubject('[Wiretap] '
            + UserInfo.getUserId()
            + '@'
            + UserInfo.getOrganizationId()
            + ' '
            + parameters.get('eda_SequenceName')
            + '#'
            + parameters.get('eda_Position')
        );
        message.setPlainTextBody(Json.serializePretty(parameters));
        message.setTargetObjectId(userId);
        message.setSaveAsActivity(false);
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{message});
        
        return Json.serialize(new List<Map<String,Object>>{parameters});
    }
}