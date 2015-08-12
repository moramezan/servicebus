public with sharing class MessageApexProcessExtension {
    
    ApexPages.StandardController controller;
    MessageModel model;
    
    public MessageApexProcessExtension(ApexPages.StandardController controller) {
        this.controller = controller;
        this.model = MessageModel.fromId(controller.getId());
    }
    
    public PageReference showApexProcess() {
        try {
            PageReference detailView = this.model.showApexProcess();
            return detailView;
            
        } catch (Exception e) {
            ApexPages.addMessages(e);
            return null;
        }
    }
    
}