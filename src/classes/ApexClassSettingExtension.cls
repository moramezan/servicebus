public with sharing class ApexClassSettingExtension {

    private ApexPages.StandardController controller;
    private ApexClassModel model;

    public ApexClassSettingExtension(ApexPages.StandardController controller) {
        this.controller = controller;
        this.model = ApexClassModel.fromId(controller.getId());
        Map<String,String> parameters = ApexPages.CurrentPage().GetParameters();
        
        try {
            DescribeSObjectResult result = this.model.describeServiceSetting();
            this.ServiceSetting = result.getName();
            this.KeyPrefix = result.getKeyPrefix();
            this.Action = result.isCustomSetting() ? 'Tab' : 'List';
            this.Isdtp = result.isCustomSetting() ? parameters.get('isdtp') : 'vw';
            
        } catch (Exception e) {
            ApexPages.addMessages(e);
            
        }
    }
    
    /**
     * Redirects the user to the tab/list view
     * of the setting held on this service.
     */
    public String ServiceSetting {get; set;}
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