public with sharing class ApexClassSettingExtension {

    private ApexPages.StandardController controller;
    private ApexClassModel model;

    public ApexClassSettingExtension(ApexPages.StandardController controller) {
        this.controller = controller;
        this.model = ApexClassModel.fromId(controller.getId());
    }
    
    public PageReference showSetting() {
        try {
            PageReference listview = this.model.showSetting();
            return listview;
            
        } catch (Exception e) {
            ApexPages.addMessages(e);
            return null;
            
        }
    }

}