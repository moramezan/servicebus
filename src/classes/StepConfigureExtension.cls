public with sharing class StepConfigureExtension {
    
    private ApexPages.StandardController controller;
    private StepModel model;
    
    public StepConfigureExtension(ApexPages.StandardController controller) {
        this.controller = controller;
        this.model = StepModel.fromId(controller.getId());
    }
    
    public PageReference doRedirect() {
        this.model.upsertConfig();
        return this.model.showConfig();
    }
}