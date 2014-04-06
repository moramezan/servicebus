public with sharing class Wiretap implements Process.Plugin {
   
    public class WiretapException extends Exception {}
      
    public class Meta {
        public SObject CustomSetting = WiretapSettings__c.SObjectType.newSObject();
        public String Icon = 'email';
        public String DocsPageUrl = Page.WiretapHelp.getUrl();
    }
    
    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult describeResult = new Process.PluginDescribeResult();
        describeResult.Name = 'Wiretap';
        describeResult.Description = 'Serializes the parameters and emails it to the user.';
        describeResult.Tag = 'Event Driven Architecture';
        return describeResult;
    }
    
    public Process.PluginResult invoke(Process.PluginRequest request) {
        Map<String,Object> parameters = request.inputParameters;
        
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
        message.setSubject('[Wiretap] ' + parameters.get('eda_SequenceName') + '#' + parameters.get('eda_Position'));
        message.setPlainTextBody(Json.serialize(parameters));
        message.setTargetObjectId(userId);
        message.setSaveAsActivity(false);
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{message});
        
        return EdaUtility.convert(new List<Map<String,Object>>{parameters});
    }
}