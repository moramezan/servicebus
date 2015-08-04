public with sharing class ApexClassHelpExtension {
    
    private ApexPages.StandardController controller;
    private ApexClassModel model;
    
    public ApexClassHelpExtension(ApexPages.StandardController controller) {
        this.controller = controller;
        this.model = ApexClassModel.fromId(controller.getId());
    }
    
    public String getTag() {
        return this.model.esb.Tag;
    }
    
    public String getName() {
        return this.model.esb.Name;
    }
    
    public String getDescription() {
        return this.model.esb.Description;
    }
    
    public String getProcessSetting() {
        return this.model.esb.ProcessSetting;
    }
    
    public String getStepConfig() {
        return this.model.esb.StepConfig;
    }
    
    public String getIcon() {
        return this.model.esb.Icon;
    }
    
    public String getHelpUrl() {
        return this.model.esb.HelpUrl;
    }
    
    public Integer getLimits() {
        return this.model.esb.Limits;
    }
    
    public String getCardinality() {
        return this.model.esb.Cardinality;
    }
    
    public Map<String,String> getInputs() {
        return this.model.esb.Inputs;
    }
    
    public Map<String,String> getOutputs() {
        return this.model.esb.Outputs;
    }
    
}