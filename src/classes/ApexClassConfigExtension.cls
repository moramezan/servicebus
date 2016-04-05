public with sharing class ApexClassConfigExtension {
    
    DescribeSObjectResult result;
    ApexPages.StandardController controller;
    ApexClassModel model;
    
    public ApexClassConfigExtension(ApexPages.StandardController controller) {
        this.controller = controller;
        this.model = ApexClassModel.fromId(controller.getId());
        Map<String,String> parameters = ApexPages.CurrentPage().GetParameters();
        
        try {
            this.result = this.model.describeServiceConfig();
            this.ServiceConfig = result.getName();
            this.KeyPrefix = result.getKeyPrefix();
            
        } catch (ApexClassModel.ModelException e) {
            ApexPages.addMessages(e);
            
        }
    }
    
    public PageReference redirect() {
        
        if (!this.result.isCustomSetting()) {
            //custom objects display list view without sidebar
            return null;
        }
        
        //custom settings display setup menu
        PageReference redirect = new PageReference('/setup/ui/listCustomSettingsData.apexp');
        redirect.getParameters().put('id', 'a0A');
        return redirect;
    }
    
    /**
     * Must use dynamic component because 'type'
     * attribute cannot be an expression.
     */
    public ApexPages.Component getListViews() {
        Component.Apex.ListViews listViews = new Component.Apex.ListViews();
        listViews.type = this.ServiceConfig;
        return listViews;
    }
    
    /**
     * Redirects the user to the tab/list view
     * of the setting held on this service.
     */
    public String ServiceConfig {get; set;}
    public String KeyPrefix {get; set;}
    
}