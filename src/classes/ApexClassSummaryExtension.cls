public with sharing class ApexClassSummaryExtension {
    
    private ApexPages.StandardController controller;
    private ApexClassModel model;
    
    public ApexClassModel.Summary Summary {get; set;}
    public String FullyQualifiedClassName {get; set;}
    
    public ApexClassSummaryExtension(ApexPages.StandardController controller) {
        this.controller = controller;
    }
    
    public void doInit() {
        this.model = ApexClassModel.fromId(controller.getId());
        
        //by doing this we keep our getters in the controller and not the esb summary class
        this.Summary = this.model.ESB;
        this.FullyQualifiedClassName = this.model.fullyQualifiedClassName();
    }
    
}