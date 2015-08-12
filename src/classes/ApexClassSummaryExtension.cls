public with sharing class ApexClassSummaryExtension {
    
    private ApexPages.StandardController controller;
    private ApexClassModel model;
    
    public Map<String,Object> Esb {get; set;}
    public Map<String,Object> Inputs {get; set;}
    public Map<String,Object> Outputs {get; set;}
    public String FullyQualifiedClassName {get; set;}
    
    public ApexClassSummaryExtension(ApexPages.StandardController controller) {
        this.controller = controller;
    }
    
    public void doInit() {
        this.model = ApexClassModel.fromId(controller.getId());
        
        //by doing this we keep our getters in the controller and not the esb summary class
        this.ESB = (Map<String,Object>)Json.deserializeUntyped(Json.serialize(this.model.ESB));
        this.Inputs = this.model.esb.Inputs;
        this.Outputs = this.model.esb.Outputs;
        this.FullyQualifiedClassName = this.model.fullyQualifiedClassName();
    }
    
}