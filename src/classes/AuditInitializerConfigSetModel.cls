public class AuditInitializerConfigSetModel extends ApexDomain.StandardSetModel {

    // this flag is used for testing only
    @testVisible
    private static Boolean isEnabled = true;
    
    public AuditInitializerConfigSetModel(List<AuditInitializerConfig__c> sobjects) {
        super(sobjects);
    }


    override public void onBeforeInsert() {
        if (isEnabled) {
            this.populateFriendlyNames();
        }
    }


    override public void onBeforeUpdate(List<SObject> oldAuditInitializerConfigs) {
        if (isEnabled) {
            this.populateFriendlyNames();
            this.resetIdentifierFields(oldAuditInitializerConfigs);
        }
    }


    private void resetIdentifierFields(List<AuditInitializerConfig__c> oldAuditInitializerConfigs) {
        List<AuditInitializerConfig__c> newAuditInitializerConfigs = (List<AuditInitializerConfig__c>)this.getRecords();
 
            Map<Id, AuditInitializerConfig__c> oldAuditInitializerConfigIdToOldAuditInitializerConfig =
                new Map<Id, AuditInitializerConfig__c>(oldAuditInitializerConfigs);

            for (AuditInitializerConfig__c newAuditInitializerConfig : newAuditInitializerConfigs) {
                AuditInitializerConfig__c oldAuditInitializerConfig =
                    oldAuditInitializerConfigIdToOldAuditInitializerConfig.get(newAuditInitializerConfig.Id);
                
                Boolean isStaticChanged = (
                    oldAuditInitializerConfig.StaticGroupIdentifier__c != newAuditInitializerConfig.StaticGroupIdentifier__c);
                Boolean isDynamicChanged = (
                    oldAuditInitializerConfig.DynamicGroupIdentifier__c != newAuditInitializerConfig.DynamicGroupIdentifier__c);
                
                if (isDynamicChanged) { // set Static to NULL
                    newAuditInitializerConfig.StaticGroupIdentifier__c = null;
                }
                if (isStaticChanged) {  // set Dynamic to NULL
                    newAuditInitializerConfig.DynamicGroupIdentifier__c = null; //chooser field name
                    newAuditInitializerConfig.DynamicGroupIdentifierObjectName__c = null; //chooser object name
                }
            }
     
    }


    private void populateFriendlyNames() {
        List<AuditInitializerConfig__c> auditInitializerConfigs = (List<AuditInitializerConfig__c>)this.getRecords();

        for (AuditInitializerConfig__c auditInitializerConfig : auditInitializerConfigs) {
            if (auditInitializerConfig.StaticGroupIdentifier__c == null && auditInitializerConfig.DynamicGroupIdentifier__c == null) {
                auditInitializerConfig.Name = ('Creates an Audit Group based on the name of this sequence.').left(80);
            } else if (auditInitializerConfig.DynamicGroupIdentifier__c != null) {
                auditInitializerConfig.Name = ('Creates an Audit Group named by "' + auditInitializerConfig.DynamicGroupIdentifier__c + '" on the message data.').left(80);
            } else if (auditInitializerConfig.StaticGroupIdentifier__c != null) {
                auditInitializerConfig.Name = ('Creates an Audit Group named "' + auditInitializerConfig.StaticGroupIdentifier__c + '".').left(80);
            }
        }
    }
}