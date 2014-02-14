public class PersistentDataReprocessExtension {
    
    static Id persistentDataId;
    
    private ApexPages.StandardController controller;
    
    public PersistentDataReprocessExtension(ApexPages.StandardController controller) {
        PersistentDataReprocessExtension.persistentDataId = controller.getId();
        this.controller = controller;
    }
    
    public PageReference doReprocess() {
        Type.forName(DoDml.class.getName()).newInstance();
        Broker.process();
        
        String prefix = SObjectType.PersistentData__c.KeyPrefix;
        return new ApexPages.PageReference('/' + prefix + '/o');
    }

    public class DoDml {
        public DoDml() {
            Database.update(new PersistentData__c(
                Id = persistentDataId,
                Message__c = null,
                Status__c = 'Reprocess'
            ));
        }
    }
    
}