public with sharing class StepConfigExtension {
    
    private ApexPages.StandardController controller;
    private StepModel model;
    
    public StepConfigExtension(ApexPages.StandardController controller) {
        this.controller = controller;
        this.model = StepModel.fromId(controller.getId());
    }
    
    public PageReference showConfig() {
        this.model.upsertConfig();
        return this.model.showConfig();
    }
}