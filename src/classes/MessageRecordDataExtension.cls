public with sharing class MessageRecordDataExtension {
    
    private ApexPages.StandardController controller;
    private MessageModel model;
    
    public MessageRecordDataExtension(ApexPages.StandardController controller) {
        this.controller = controller;
        this.model = MessageModel.fromId(controller.getId());
    }
    
    public PageReference showRecordData() {
        try {
            PageReference detailView = model.showRecordData();
            return detailView;
            
        } catch (Exception e) {
            ApexPages.addMessages(e);
            return null;
        }
    }

}