public with sharing class Wiretap {
   
    public String Parameters;
    
    public class ESB {
        public String Tag = 'Enterprise Service Bus';
        public String Name = 'Wiretap';
        public String Description = 'Emails the message parameters to the user.';
        public SObject ProcessSetting = WiretapSetting__c.SObjectType.newSObject();
        public String Icon = 'email';
        public String HelpUrl = Page.GateItemCsh.getUrl();
        public Integer Limits = 5; //leave half of 10 (Total number of sendEmail methods allowed)
    }
    
    override public String toString() {
        Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(this.Parameters);
        
        Id userId;
        try {
            WiretapSetting__c setting = WiretapSetting__c.getInstance();
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
            + parameters.get('__SequenceName')
            + '#'
            + parameters.get('__Position')
        );
        message.setPlainTextBody(Json.serializePretty(parameters));
        message.setTargetObjectId(userId);
        message.setSaveAsActivity(false);
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{message});
        
        return Json.serialize(new List<Map<String,Object>>{parameters});
    }
}