public with sharing class MessageRestartExtension {
    
    ApexPages.StandardSetController controller;
    static MessageSetModel model;
    
    public MessageRestartExtension(ApexPages.StandardSetController controller) {
        this.controller = controller;
        model = new MessageSetModel(controller.getSelected());
    }
    
    public PageReference doRestart() {
        try {
            //avoids DML in action method
            Type.forName(DoDml.class.getName()).newInstance();
            
        } catch (MessageSetModel.ModelException e) {
            //failure, eg you are not allowed to restart any of those messages
            ApexPages.addMessages(e);
            return null;
        }
        
        //success, refreshes the list view
        return Page.MessageList;
    }
    
    public class DoDml {
        public DoDml() {
            model.restart();
        }
    }
    
}