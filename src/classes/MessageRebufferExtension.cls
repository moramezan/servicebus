public with sharing class MessageRebufferExtension {
    
    private ApexPages.StandardController controller;
    @TestVisible static private Message__c message;
    
    public MessageRebufferExtension(ApexPages.StandardController controller) {
        this.controller = controller;
        message = (Message__c)ApexDomain.getById(controller.getId());
    }
    
    public PageReference doRebuffer() {
        //we are happy for Queued, Buffered or Started guys to be force-Processed
        //but we just note that a Queued message will need to be resolved first!
        
        if (message.Status__c != 'Started') {
            //prevent inadvertent replay!
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, 'Only messages with "Started" status can be restarted.'));
            return null;
        }
        
        //do special run once broker
        Job.ExecAnonResult result;
        if (!Test.isRunningTest()) {
            //in real life, usurp sysadmin
            result = Job.runOneAsUser(message.Id);
        } else {
            //in tests, just run the thing
            Job.runOne(message.Id);
            result = new Job.ExecAnonResult();
            result.success = true;
        }
        
        if (!result.success) {
            //write status and any exception fields ("avoids DML in action method")
            message.Exception__c = result.exceptionMessage;
            message.Cause__c = result.exceptionStackTrace;
            Type.forName(DoDml.class.getName()).newInstance();
            
            //redirect back to detail view
            return this.controller.view();
        } else {
            //when successful, restart the REAL broker to carry on with the outputs
            Broker.run();
            
            //redirect back to list view
            return new ApexPages.PageReference('/' + SObjectType.Message__c.KeyPrefix);
        }
    }

    public class DoDml {
        public DoDml() {
            if (!SObjectType.Message__c.Fields.Status__c.Updateable) throw new ApexDomain.FlsException('!SObjectType.Message__c.Fields.Status__c.Updateable');
            if (!SObjectType.Message__c.Fields.Exception__c.Updateable) throw new ApexDomain.FlsException('!SObjectType.Message__c.Fields.Exception__c.Updateable');
            if (!SObjectType.Message__c.Fields.Cause__c.Updateable) throw new ApexDomain.FlsException('!SObjectType.Message__c.Fields.Cause__c.Updateable');
            
            update message;
        }
    }
    
}