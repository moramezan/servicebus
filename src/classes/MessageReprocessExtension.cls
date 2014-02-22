public class MessageReprocessExtension {
    
    static Id messageId;
    
    private ApexPages.StandardController controller;
    
    public MessageReprocessExtension(ApexPages.StandardController controller) {
        MessageReprocessExtension.messageId = controller.getId();
        this.controller = controller;
    }
    
    public PageReference doReprocess() {
        Type.forName(DoDml.class.getName()).newInstance();
        Broker.process();
        
        String prefix = SObjectType.Message__c.KeyPrefix;
        return new ApexPages.PageReference('/' + prefix + '/o');
    }

    public class DoDml {
        public DoDml() {
            Database.update(new Message__c(
                Id = messageId,
                Message__c = null,
                Status__c = 'Reprocess'
            ));
        }
    }
    
}