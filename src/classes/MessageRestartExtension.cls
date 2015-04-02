public with sharing class MessageRestartExtension {
    
    private ApexPages.StandardController controller;
    static private MessageModel model;
    static private Boolean success;
    
    public MessageRestartExtension(ApexPages.StandardController controller) {
        this.controller = controller;
        model = MessageModel.fromId(controller.getId());
    }
    
    public PageReference doRestart() {
        try {
            //avoids DML in action method
            Type.forName(DoDml.class.getName()).newInstance();
            
        } catch (MessageModel.MessageException e) {
            //eg you are not allowed to restart this message
            ApexPages.addMessages(e);
            return null;
        }
        
        if (success) {
            //success, takes them back to list view (cancel does not achieve that)
            return new ApexPages.PageReference('/' + SObjectType.Message__c.KeyPrefix);
        } else {
            //failure, refreshes this detail page again
            return this.controller.view();
        }
    }
    
    public class DoDml {
        public DoDml() {
            success = model.restart();
        }
    }
    
}