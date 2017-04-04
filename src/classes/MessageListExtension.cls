public with sharing class MessageListExtension {
    
    public ApexPages.StandardSetController SetController;
    public ApexPages.StandardSetController MessageSetController {public get; private set;}
    
    public MessageListExtension(ApexPages.StandardSetController setController) {
        this.SetController = setController;
    
        //set up message standard set controller
        this.MessageSetController = new ApexPages.StandardSetController(buildQueryLocator());
        this.MessageSetController.setPageSize(100);
    }
    
    public void doInit() {
        try {
            Type.forName(DoDml.class.getName()).newInstance();
        } catch (Exception e) {
            e.setMessage('MessageListExtension.doInit: ' + e.getMessage());
            ApexPages.addMessages(e);
        }
    }
    
    public PageReference doPause() {
        MessageSetModel.pauseQueue();
        PageReference messageList = Page.MessageList;
        messageList.setRedirect(true);
        return messageList;
    }
    
    public PageReference doResume() {
        MessageSetModel.resumeQueue();
        PageReference messageList = Page.MessageList;
        messageList.setRedirect(true);
        return messageList;
    }
    
    static private Database.QueryLocator buildQueryLocator() {
        String query = ''
            + ' SELECT Id, Name, CreatedDate, Status__c, Route__c, ExecuteDuration__c, Exception__c'
            + ' FROM Message__c'
            + ' WHERE Status__c = \'Completed\''
            + ' AND Exception__c = null'
            + ' ORDER BY CreatedDate DESC'
            + ' LIMIT 10000'
            + ' ALL ROWS'
        ;
        
        return Database.getQueryLocator(query);
    }
    
    public class DoDml {
        public DoDml() {
            //avoids dml in action method
            MessageSetModel.locateFailedOneShots().healExtendedStatus();
        }
    }
}