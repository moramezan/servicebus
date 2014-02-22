public with sharing class StepShowConfigurationExtension {
    
    private ApexPages.StandardController controller;
    
    public StepShowConfigurationExtension(ApexPages.StandardController controller) {
        this.controller = controller;
    }
    
    /**
     * This resolves the Configuration record for a given Step so that
     * it can be accessed from the native interface via a Custom Button.
     */
    public PageReference doRedirect() {
        Step__c step = (Step__c)SalesforceObject.getById(this.controller.getId());
        if (null == step.ConfigurationId__c) {
            //process has no configuration, go back
            return new ApexPages.StandardController(step).view();
        } else {
            //real config exists, show detail page
            return new ApexPages.StandardController(SalesforceObject.getById(step.ConfigurationId__c)).view();
        }
    }
    
}