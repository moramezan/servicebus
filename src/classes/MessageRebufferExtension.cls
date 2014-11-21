public with sharing class MessageRebufferExtension {
    
    @TestVisible static private Message__c message;
    
    public MessageRebufferExtension(ApexPages.StandardController controller) {
        message = (Message__c)SalesforceObject.getById(controller.getId());
    }
    
    public PageReference doRebuffer() {
        //we are happy for Queued, Buffered or Started guys to be force-Processed
        //but we just note that a Queued message will need to be resolved first!
        if (message.Status__c == 'Queued') {
            //message was paused, resolve here
            Broker.impl().resolve(new List<Message__c>{message}); //RESOLVE
        }
        
        //write away status and any resolved fields ("avoids DML in action method")
        Type.forName(DoDml.class.getName()).newInstance();
        
        //restart the broker
        Broker.process();
        
        //redirect back to list view
        return new ApexPages.PageReference('/' + SObjectType.Message__c.KeyPrefix);
    }

    public class DoDml {
        public DoDml() {
            if (!SObjectType.Message__c.Fields.Status__c.Updateable) throw new Broker.FlsException('!SObjectType.Message__c.Fields.Status__c.Updateable');
            if (!SObjectType.Message__c.Fields.Exception__c.Updateable) throw new Broker.FlsException('!SObjectType.Message__c.Fields.Exception__c.Updateable');
                  
            message.Exception__c = null;
            message.Status__c = 'Rebuffered';
            update message;
        }
    }
    
}