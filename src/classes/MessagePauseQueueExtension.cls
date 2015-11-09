public with sharing class MessagePauseQueueExtension {
    
    ApexPages.StandardSetController controller;
    
    public MessagePauseQueueExtension(ApexPages.StandardSetController controller) {
        this.controller = controller;
    }
    
    public PageReference doPause() {
        try {
            //update IsPaused setting ("avoids DML in action method")
            Type.forName(DoDml.class.getName()).newInstance();
            
        } catch (Exception e) {
            ApexPages.addMessages(e);
            return null;
        }
        
        //redirect to list view - only works with "Display Checkboxes (for Multi-Record Selection)" on button
        return new ApexPages.Action('{!List}').invoke();
    }
    
    public class DoDml {
        public DoDml() {
            MessageSetModel.pauseQueue();
        }
    }
}