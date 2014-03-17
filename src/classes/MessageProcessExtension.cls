public with sharing class MessageProcessExtension {
    
    static private Message__c message;
    
    public MessageProcessExtension(ApexPages.StandardController controller) {
        message = [
            SELECT Id, Status__c, Parameters__c
            FROM Message__c
            WHERE Id = :controller.getId()
        ];
    }
    
    public PageReference doProcess() {
        //we are happy for Queued, Buffered or Processing guys to be force-Processed
        //but we just note that a Queued message will need to be resolved first!
        if (message.Status__c == 'Queued') {
            //message was paused, resolve here
            Broker.resolve(new List<Message__c>{message}); //RESOLVE
        }
        
        //write away status and any resolved fields ("avoids DML in action method")
        Type.forName(DoDml.class.getName()).newInstance(); //PERSIST
        
        //restart the broker
        Broker.process();
        
        //redirect back to list view
        return new ApexPages.PageReference('/' + SObjectType.Message__c.KeyPrefix);
    }

    public class DoDml {
        public DoDml() {
            message.Exception__c = null;
            message.Status__c = 'Reprocess';
            update message;
        }
    }
    
}