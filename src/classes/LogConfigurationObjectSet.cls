public class LogConfigurationObjectSet extends SalesforceObjectSet {

    // this flag is used for testing only
    @testVisible
    private static Boolean isEnabled = true;
    
    public LogConfigurationObjectSet(List<LogConfiguration__c> sobjects) {
        super(sobjects);
    }


    override public void onBeforeInsert() {
        if (isEnabled) {
            this.populateFriendlyNames();
        }
    }


    override public void onBeforeUpdate(List<SObject> oldLogConfigurations) {
        if (isEnabled) {
            this.populateFriendlyNames();
            this.resetIdentifierFields(oldLogConfigurations);
        }
    }


    private void resetIdentifierFields(List<LogConfiguration__c> oldLogConfigurations) {
        List<LogConfiguration__c> newLogConfigurations = (List<LogConfiguration__c>)this.getSObjects();
 
            Map<Id, LogConfiguration__c> oldLogConfigurationIdToOldLogConfiguration =
                new Map<Id, LogConfiguration__c>(oldLogConfigurations);

            for (LogConfiguration__c newLogConfiguration : newLogConfigurations) {
                LogConfiguration__c oldLogConfiguration =  
                    oldLogConfigurationIdToOldLogConfiguration.get(newLogConfiguration.Id);
                
                Boolean isStaticChanged = (
                    oldLogConfiguration.StaticGroupIdentifier__c != newLogConfiguration.StaticGroupIdentifier__c);
                Boolean isDynamicChanged = (
                    oldLogConfiguration.DynamicGroupIdentifier__c != newLogConfiguration.DynamicGroupIdentifier__c);
                
                if (isDynamicChanged) { // set Static to NULL
                    newLogConfiguration.StaticGroupIdentifier__c = null;
                }
                if (isStaticChanged) {  // set Dynamic to NULL
                    newLogConfiguration.DynamicGroupIdentifier__c = null; //chooser field name
                    newLogConfiguration.DynamicGroupIdentifierObjectName__c = null; //chooser object name
                }
            }
     
    }


    private void populateFriendlyNames() {
        List<LogConfiguration__c> logConfigurations = (List<LogConfiguration__c>)this.getSObjects();

        for (LogConfiguration__c logConfiguration : logConfigurations) {
            if (logConfiguration.StaticGroupIdentifier__c == null && logConfiguration.DynamicGroupIdentifier__c == null) {
                logConfiguration.Name = ('Creates a Log Group based on the name of this sequence.').left(80);
            } else if (logConfiguration.DynamicGroupIdentifier__c != null) {
                logConfiguration.Name = ('Creates a Log Group named by "' + logConfiguration.DynamicGroupIdentifier__c + '" on the message data.').left(80);
            } else if (logConfiguration.StaticGroupIdentifier__c != null) {
                logConfiguration.Name = ('Creates a Log Group named "' + logConfiguration.StaticGroupIdentifier__c + '".').left(80);
            }
        }
    }
}