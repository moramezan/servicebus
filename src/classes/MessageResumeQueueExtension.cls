public with sharing class MessageResumeQueueExtension {
    
    ApexPages.StandardSetController controller;
    
    public MessageResumeQueueExtension(ApexPages.StandardSetController controller) {
        this.controller = controller;
    }
    
    public PageReference doResume() {
        try {
            //update IsPaused setting and update Message statuses ("avoids DML in action method")
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
            MessageSetModel.resumeQueue();
        }
    }
}