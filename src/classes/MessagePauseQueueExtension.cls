public with sharing class MessagePauseQueueExtension {

    public MessagePauseQueueExtension(ApexPages.StandardSetController controller) {
        //
    }
    
    public PageReference doPause() {
        //update IsPaused setting ("avoids DML in action method")
        Type.forName(MessagePauseQueueExtension.DoDml.class.getName()).newInstance();
        
        //redirect to list view
        return new PageReference('/' + SObjectType.Message__c.KeyPrefix);
    }
    
    public class DoDml {
        public DoDml() {
            //fetch custom setting or create for the first time
            BrokerSetting__c setting = BrokerSetting__c.getOrgDefaults();
            if (setting == null) setting = new BrokerSetting__c();
            
            //unset the flag
            setting.IsPaused__c = true;
            upsert setting;
        }
    }
    
}