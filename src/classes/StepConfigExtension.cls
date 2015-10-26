public with sharing class StepConfigExtension {
    
    private ApexPages.StandardController controller;
    private StepModel model;
    
    public StepConfigExtension(ApexPages.StandardController controller) {
        this.controller = controller;
        this.model = StepModel.fromId(controller.getId());
        Map<String,String> parameters = ApexPages.CurrentPage().GetParameters();
        
        try {
            DescribeSObjectResult result = this.model.describeStepConfig();
            this.StepConfig = result.getName();
            this.Isdtp = result.isCustomSetting() ? parameters.get('isdtp') : 'vw';
            
        } catch (Exception e) {
            ApexPages.addMessages(e);
            
        }
    }
    
    /**
     * Redirects the user to the detail view
     * of the config record held on this step.
     */
    public String StepConfig {get; set;}
    
    /**
     * normal style for custom settings
     * console style only for custom objects
     */
    public String Isdtp {get; set;}
    
}