public with sharing class StepConfigExtension {
    
    private ApexPages.StandardController controller;
    private StepModel model;
    
    public StepConfigExtension(ApexPages.StandardController controller) {
        this.controller = controller;
        this.model = StepModel.fromId(controller.getId());
    }
    
    /**
     * Redirects the user to the detail view
     * of the config record held on this step.
     *
     * normal style for custom settings
     * console style only for custom objects
     */
    public PageReference doRedirect() {
        this.model.upsertConfig();
        return this.model.showConfig();
    }
    
}