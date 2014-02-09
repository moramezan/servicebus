public with sharing class ChainStepShowConfigurationExtension {
    
    private ApexPages.StandardController controller;
    
    public ChainStepShowConfigurationExtension(ApexPages.StandardController controller) {
        this.controller = controller;
    }
    
    /**
     * This resolves the Configuration record for a given Chain Step so that
     * it can be accessed from the native interface via a Custom Button.
     */
    public PageReference doRedirect() {
        ChainStep__c chainStep = (ChainStep__c)SalesforceObject.getById(this.controller.getId());
        if (null == chainStep.ConfigurationId__c) {
            //process has no configuration, go back
            return new ApexPages.StandardController(chainStep).view();
        } else {
            //real config exists, show detail page
            return new ApexPages.StandardController(SalesforceObject.getById(chainStep.ConfigurationId__c)).view();
        }
    }
    
}