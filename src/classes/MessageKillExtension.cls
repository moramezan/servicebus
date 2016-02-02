public with sharing class MessageKillExtension {

    ApexPages.StandardSetController controller;
    static MessageSetModel model;
    
    public MessageKillExtension(ApexPages.StandardSetController controller) {
        this.controller = controller;
        model = new MessageSetModel(controller.getSelected());
    }
    
    public PageReference doKill() {
        try {
            //avoids DML in action method
            Type.forName(DoDml.class.getName()).newInstance();
            
        } catch (MessageSetModel.ModelException e) {
            //failure, eg you are not allowed to kill any of those messages
            ApexPages.addMessages(e);
            return null;
        }
        
        //success, takes them back to list view (cancel does not achieve that)
        return Page.MessageList;
    }
    
    public class DoDml {
        public DoDml() {
            model.kill();
        }
    }

}