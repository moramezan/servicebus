public class Wiretap extends ApexClassModel.BaseProcess {
    
    /**
     * @docs ProcessWiretap.html
     */
    public class ESB extends ApexClassModel.BaseSummary {
        String Tag = 'Enterprise Service Bus';
        String Name = 'Wiretap';
        String Description = 'Emails the message parameters to the user.';
        String ProcessSetting = WiretapSetting__c.class.getName();
        String Icon = 'email';
        String HelpUrl = new PageReference('/apex/ContextSensitiveHelp?topic=ProcessWiretap').getUrl();
        Integer Limits = 5; //leave half of 10 (Total number of sendEmail methods allowed)
        String Cardinality = 'One';
    }
    
    List<Map<String,Object>> execute(Map<String,Object> parameters) {
        
        Id userId;
        try {
            WiretapSetting__c setting = WiretapSetting__c.getOrgDefaults();
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
        
        return new List<Map<String,Object>>{parameters};
    }
}