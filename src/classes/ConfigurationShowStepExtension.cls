public class ConfigurationShowStepExtension {
    
    private ApexPages.StandardController controller;
    
    public ConfigurationShowStepExtension(ApexPages.StandardController controller) {
        this.controller = controller;
    }
    
    /**
     * This resolves the Chain Step record for a given Configuration so that
     * it can be accessed from the native interface via a Custom Button.
     */
    public PageReference doRedirect() {
        ChainStep__c chainStep = [
            SELECT Id
            FROM ChainStep__c
            WHERE ConfigurationId__c = :(Id)this.controller.getId()
        ];
        return new ApexPages.StandardController(chainStep).view();
    }
    
}