public class LogConfigObjectSet extends SalesforceObjectSet {

    // this flag is used for testing only
    @testVisible
    private static Boolean isEnabled = true;
    
    public LogConfigObjectSet(List<LogConfig__c> sobjects) {
        super(sobjects);
    }


    override public void onBeforeInsert() {
        if (isEnabled) {
            this.populateFriendlyNames();
        }
    }


    override public void onBeforeUpdate(List<SObject> oldLogConfigs) {
        if (isEnabled) {
            this.populateFriendlyNames();
            this.resetIdentifierFields(oldLogConfigs);
        }
    }


    private void resetIdentifierFields(List<LogConfig__c> oldLogConfigs) {
        List<LogConfig__c> newLogConfigs = (List<LogConfig__c>)this.getSObjects();
 
            Map<Id, LogConfig__c> oldLogConfigIdToOldLogConfig =
                new Map<Id, LogConfig__c>(oldLogConfigs);

            for (LogConfig__c newLogConfig : newLogConfigs) {
                LogConfig__c oldLogConfig =  
                    oldLogConfigIdToOldLogConfig.get(newLogConfig.Id);
                
                Boolean isStaticChanged = (
                    oldLogConfig.StaticGroupIdentifier__c != newLogConfig.StaticGroupIdentifier__c);
                Boolean isDynamicChanged = (
                    oldLogConfig.DynamicGroupIdentifier__c != newLogConfig.DynamicGroupIdentifier__c);
                
                if (isDynamicChanged) { // set Static to NULL
                    newLogConfig.StaticGroupIdentifier__c = null;
                }
                if (isStaticChanged) {  // set Dynamic to NULL
                    newLogConfig.DynamicGroupIdentifier__c = null; //chooser field name
                    newLogConfig.DynamicGroupIdentifierObjectName__c = null; //chooser object name
                }
            }
     
    }


    private void populateFriendlyNames() {
        List<LogConfig__c> logConfigs = (List<LogConfig__c>)this.getSObjects();

        for (LogConfig__c logConfig : logConfigs) {
            if (logConfig.StaticGroupIdentifier__c == null && logConfig.DynamicGroupIdentifier__c == null) {
                logConfig.Name = ('Creates a Log Group based on the name of this sequence.').left(80);
            } else if (logConfig.DynamicGroupIdentifier__c != null) {
                logConfig.Name = ('Creates a Log Group named by "' + logConfig.DynamicGroupIdentifier__c + '" on the message data.').left(80);
            } else if (logConfig.StaticGroupIdentifier__c != null) {
                logConfig.Name = ('Creates a Log Group named "' + logConfig.StaticGroupIdentifier__c + '".').left(80);
            }
        }
    }
}