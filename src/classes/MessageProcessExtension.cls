public with sharing class MessageProcessExtension {
    
    ApexPages.StandardController controller;
    MessageModel model;
    
    public MessageProcessExtension(ApexPages.StandardController controller) {
        this.controller = controller;
        this.model = MessageModel.fromId(controller.getId());
    }
    
    public PageReference showProcess() {
        try {
            PageReference redirect = this.model.showApexClass();
            return redirect;
        } catch (Exception e) {
            ApexPages.addMessages(e);
            return null;
        }
    }
    
}