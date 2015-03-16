public with sharing class MessageKillExtension {

    ApexPages.StandardSetController controller;
    @TestVisible static private List<Message__c> messages;
    
    public MessageKillExtension(ApexPages.StandardSetController controller) {
        this.controller = controller;
    } 
    
    public PageReference doKill() {
        Set<Id> messageIds = new Map<Id,SObject>(this.controller.getSelected()).keySet();
        messages = [SELECT Id, Status__c FROM Message__c WHERE Id IN :messageIds AND Status__c = 'Started'];
        for (Message__c message : messages) message.Status__c = 'Completed';
        
        //write status ("avoids DML in action method")
        Type.forName(DoDml.class.getName()).newInstance();
        return new ApexPages.PageReference('/' + SObjectType.Message__c.KeyPrefix);
    }
    
    public class DoDml {
        public DoDml() {
            update messages;
            //restart REAL broker
            Broker.run();
        }
    }

}