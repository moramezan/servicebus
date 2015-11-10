public with sharing class MessageRecordDataExtension {
    
    ApexPages.StandardController controller;
    MessageModel model;
    
    public MessageRecordDataExtension(ApexPages.StandardController controller) {
        this.controller = controller;
        this.model = MessageModel.fromId(controller.getId());
    }
    
    public PageReference showRecordData() {
        try {
            PageReference detailView = this.model.showRecordData();
            return detailView;
            
        } catch (MessageModel.ModelException e) {
            ApexPages.addMessages(e);
            return null;
        }
    }

}