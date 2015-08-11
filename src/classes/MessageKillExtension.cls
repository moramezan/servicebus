public with sharing class MessageKillExtension {

    private ApexPages.StandardSetController controller;
    static private MessageSetModel model;
    
    public MessageKillExtension(ApexPages.StandardSetController controller) {
        this.controller = controller;
        model = new MessageSetModel(controller.getSelected());
    }
    
    public PageReference doKill() {
        try {
            //avoids DML in action method
            Type.forName(DoDml.class.getName()).newInstance();
            
        } catch (Exception e) {
            //failure, eg you are not allowed to kill any of those messages
            ApexPages.addMessages(e);
            return null;
        }
        
        //success, takes them back to list view (cancel does not achieve that)
        return new ApexPages.PageReference('/' + SObjectType.Message__c.KeyPrefix);
    }
    
    public class DoDml {
        public DoDml() {
            model.kill();
        }
    }

}