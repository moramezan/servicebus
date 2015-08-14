public with sharing class ApexClassSummaryExtension {
    
    private ApexPages.StandardController controller;
    private ApexClassModel model;
    
    public ApexClassModel.Summary Summary {get; set;}
    public String FullyQualifiedClassName {get; set;}
    
    public ApexClassSummaryExtension(ApexPages.StandardController controller) {
        this.controller = controller;
    }
    
    public void doInit() {
        try {
            this.model = ApexClassModel.fromId(controller.getId());
            this.Summary = new ApexClassModel.Summary(model.Reflector);
            this.FullyQualifiedClassName = model.Reflector.getName();
        } catch (Exception e) {
            ApexPages.addMessages(e);
        }
    }
    
}