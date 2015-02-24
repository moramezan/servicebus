public with sharing class MessageRebufferExtension {
    
    @TestVisible static private Message__c message;
    
    public MessageRebufferExtension(ApexPages.StandardController controller) {
        message = (Message__c)ApexDomain.getById(controller.getId());
    }
    
    public PageReference doRebuffer() {
        //we are happy for Queued, Buffered or Started guys to be force-Processed
        //but we just note that a Queued message will need to be resolved first!
        
        //write away status and any resolved fields ("avoids DML in action method")
        Type.forName(DoDml.class.getName()).newInstance();
        
        //restart the broker
        Job.process();
        
        //redirect back to list view
        return new ApexPages.PageReference('/' + SObjectType.Message__c.KeyPrefix);
    }

    public class DoDml {
        public DoDml() {
            if (!SObjectType.Message__c.Fields.Status__c.Updateable) throw new ApexDomain.FlsException('!SObjectType.Message__c.Fields.Status__c.Updateable');
            if (!SObjectType.Message__c.Fields.Exception__c.Updateable) throw new ApexDomain.FlsException('!SObjectType.Message__c.Fields.Exception__c.Updateable');
            if (!SObjectType.Message__c.Fields.Cause__c.Updateable) throw new ApexDomain.FlsException('!SObjectType.Message__c.Fields.Cause__c.Updateable');
            
            message.Exception__c = null;
            message.Cause__c = null;
            message.Status__c = 'Rebuffered';
            update message;
        }
    }
    
}