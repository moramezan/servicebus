public with sharing class ApexClassConfigExtension {

    ApexPages.StandardController controller;
    ApexClassModel model;

    public ApexClassConfigExtension(ApexPages.StandardController controller) {
        this.controller = controller;
        this.model = ApexClassModel.fromId(controller.getId());
        Map<String,String> parameters = ApexPages.CurrentPage().GetParameters();
        
        try {
            DescribeSObjectResult result = this.model.describeServiceConfig();
            this.ServiceConfig = result.getName();
            this.KeyPrefix = result.getKeyPrefix();
            this.Action = result.isCustomSetting() ? 'Tab' : 'List';
            this.Isdtp = result.isCustomSetting() ? parameters.get('isdtp') : 'vw';
            
        } catch (ApexClassModel.ModelException e) {
            ApexPages.addMessages(e);
            
        }
    }
    
    /**
     * Redirects the user to the tab/list view
     * of the setting held on this service.
     */
    public String ServiceConfig {get; set;}
    public String KeyPrefix {get; set;}
    
    /**
     * tab suffix only for custom settings
     * list suffix for custom objects
     */
    public String Action {get; set;}
    
    /**
     * normal style for custom settings
     * console style only for custom objects
     */
    public String Isdtp {get; set;}
    
    
}