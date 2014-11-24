public with sharing class ConfigStepExtension {
    
    private ApexPages.StandardController controller;
    
    public ConfigStepExtension(ApexPages.StandardController controller) {
        this.controller = controller;
    }
    
    /**
     * This resolves the Step record for a given Config so that
     * it can be accessed from the native interface via a Custom Button.
     */
    public PageReference doRedirect() {
        Step__c step = [
            SELECT Id
            FROM Step__c
            WHERE ConfigId__c = :(Id)this.controller.getId()
        ];
        return new ApexPages.StandardController(step).view();
    }
    
}