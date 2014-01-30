public with sharing class Wiretap implements Process.Plugin {
   
    public class WiretapException extends Exception {}
      
    public class Eda {
        public SObject customizable = WiretapCustomization__c.SObjectType.newSObject();
        public String icon = 'email';
    }
    
    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult describeResult = new Process.PluginDescribeResult();
        describeResult.Name = 'Wiretap';
        describeResult.Description = 'No-op process that forwards the serialized Notification to the email of the running context user';
        describeResult.Tag = 'Event Driven Architecture';
        return describeResult;
    }
    
    public Process.PluginResult invoke(Process.PluginRequest request) {
        Map<String,Object> notification = request.inputParameters;
        
        Id userId;
        try {
            WiretapCustomization__c setting = WiretapCustomization__c.getInstance();
            userId = setting.UserId__c;
        } catch (Exception e) {
        }
        if (userId == null) {
            userId = UserInfo.getUserId();   
        }

        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.setSubject('[Wiretap] ' + notification.get('eda__chainName') + '#' + notification.get('eda__sequence'));
        message.setPlainTextBody(Json.serialize(notification));
        message.setTargetObjectId(userId);
        message.setSaveAsActivity(false);
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{message});
        
        return Utility.convert(new List<Map<String,Object>>{notification});
    }
}