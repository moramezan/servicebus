public with sharing class MessageResumeQueueExtension {

    public MessageResumeQueueExtension(ApexPages.StandardSetController controller) {
        //
    }
    
    public PageReference doResume() {
        //update IsPaused setting and update Message statuses ("avoids DML in action method")
        Type.forName(MessageResumeQueueExtension.DoDml.class.getName()).newInstance();
        
        //restart the broker
        Broker.process();
        
        //redirect to list view
        return new PageReference('/' + SObjectType.Message__c.KeyPrefix);
    }
    
    public class DoDml {
        public DoDml() {
            if (!SObjectType.Message__c.Fields.Status__c.Updateable) throw new Broker.FlsException('!SObjectType.Message__c.Fields.Status__c.Updateable');
        
            //fetch custom setting or create for the first time
            BrokerSettings__c setting = BrokerSettings__c.getOrgDefaults();
            if (setting == null) setting = new BrokerSettings__c();
            
            //unset the flag
            setting.IsPaused__c = false;
            upsert setting;
            
            //get all the queued guys
            List<Message__c> messages = [
                SELECT Id, Parameters__c
                FROM Message__c
                WHERE Status__c = 'Queued'
                LIMIT :Limits.getLimitDMLRows() //if more than 10,000 you could click Resume multiple times
            ];
            
            //Why do we have an extra status Queued?
            //So that they can be excluded from the RESOLVE / MARK cycle at a very early stage.
            //We want to be able to reintroduce messages on a one-by-one basis without turning on the tap.
            
            //advance them from Queued to Buffer
            for (Message__c message : messages) {
                message.Status__c = 'Buffer';
            }
            
            //RESOLVE
            Broker.impl().resolve(messages);
            
            update messages;
        }
    }
}