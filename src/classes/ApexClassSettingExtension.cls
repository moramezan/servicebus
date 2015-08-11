public with sharing class ApexClassSettingExtension {

    private ApexPages.StandardController controller;
    private ApexClassModel model;

    public ApexClassSettingExtension(ApexPages.StandardController controller) {
        this.controller = controller;
        this.model = ApexClassModel.fromId(controller.getId());
    }
    
    public PageReference doRedirect() {
        try {
            return this.model.showProcessConfig();
        } catch (Exception e) {
            ApexPages.addMessages(e);
            return null;
        }
    }

}