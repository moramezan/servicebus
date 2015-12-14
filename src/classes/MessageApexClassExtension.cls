public with sharing class MessageApexClassExtension {
    
    ApexPages.StandardController controller;
    MessageModel model;
    
    public MessageApexClassExtension(ApexPages.StandardController controller) {
        this.controller = controller;
        this.model = MessageModel.fromId(controller.getId());
    }
    
    public PageReference showApexClass() {
        try {
            PageReference detailView = this.model.showApexClass();
            return detailView;
            
        } catch (ApexClassModel.ModelException e) {
            ApexPages.addMessages(e);
            return null;
        }
    }
    
}