public with sharing class MessageRebufferExtension {
    
    private ApexPages.StandardSetController controller;
    @TestVisible static private List<Message__c> messages;
    
    public MessageRebufferExtension(ApexPages.StandardSetController controller) {
        this.controller = controller;
    }
    
    public PageReference doRebuffer() {
        Set<Id> messageIds = new Map<Id,SObject>(this.controller.getSelected()).keySet();
        messages = [SELECT Id, Status__c FROM Message__c WHERE Id IN :messageIds AND Status__c = 'Started'];
        for (Message__c message : messages) {
            message.Status__c = 'Buffered';
            message.Exception__c = null; //#827
            message.Cause__c = null; //#827
        }
        
        //write status and any exception fields ("avoids DML in action method")
        Type.forName(DoDml.class.getName()).newInstance();
        return new ApexPages.PageReference('/' + SObjectType.Message__c.KeyPrefix);
    }
    
    public class DoDml {
        public DoDml() {
            update messages;
            
            // #653 don't use a @Future call unless necessary
            if (Broker.impl().isRunning()) return;
            
            //restart REAL broker
            if (!Test.isRunningTest()) {
                //in real life, usurp sysadmin
                Job.runAsUser();
            } else {
                //in tests, just run the thing
                Job.run();
            }
        }
    }
    
}