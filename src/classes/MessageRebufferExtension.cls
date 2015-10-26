public with sharing class MessageRebufferExtension {
    
    private ApexPages.StandardSetController controller;
    static private MessageSetModel model;
    
    public MessageRebufferExtension(ApexPages.StandardSetController controller) {
        this.controller = controller;
        model = new MessageSetModel(controller.getSelected());
    }
    
    public PageReference doRebuffer() {
        try {
            //avoids DML in action method
            Type.forName(DoDml.class.getName()).newInstance();
            
        } catch (Exception e) {
            //failure, eg you are not allowed to rebuffer any of those messages
            ApexPages.addMessages(e);
            return null;
        }
        
        //success, refreshes the list view
        return new ApexPages.Action('{!List}').invoke();
    }
    
    public class DoDml {
        public DoDml() {
            model.rebuffer();
        }
    }
    
}