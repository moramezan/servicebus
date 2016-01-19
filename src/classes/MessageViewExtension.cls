public with sharing class MessageViewExtension {
    
    static MessageModel dmlModel;
    ApexPages.StandardController controller;
    public Message__c Message {get; set;}
    public List<Message__c> Children {get; set;}
    
    public MessageViewExtension(ApexPages.StandardController controller) {
        this.controller = controller;
    }
    
    public PageReference doInit() {
        
        if (this.controller.getId() != null) {
            //get away from standard controller
            PageReference redirect = Page.MessageView;
            redirect.getParameters().put('mid', this.controller.getId());
            redirect.setredirect(true); //prevents internal error
            return redirect;
        }
        
        String mid = ApexPages.currentPage().getParameters().get('mid');
        
        this.Message = [
            SELECT Id, Name, CreatedDate, Status__c, Route__c, ExecuteDuration__c, Exception__c, Cause__c, Event__c, JobId__c, ParentId__c
            FROM Message__c
            WHERE Id = :mid
            ALL ROWS
        ];
        
        this.Children = [
            SELECT Id, Name, CreatedDate, Status__c, Route__c, ExecuteDuration__c, Exception__c
            FROM Message__c
            WHERE ParentId__c = :mid
            ALL ROWS
        ];
        
        try {
            dmlModel = MessageModel.fromId(mid);
            Type.forName(DoDml.class.getName()).newInstance();
        } catch (Exception e) {
            ApexPages.addMessages(e);
        }
        
        return null;
    }
    
    public PageReference showService() {
        MessageModel model = new MessageModel(this.Message);
        
        try {
            PageReference detailView = model.showApexClass();
            return detailView;
            
        } catch (MessageModel.ModelException e) {
            ApexPages.addMessages(e);
            return null;
        }
    }
    
    public PageReference showData() {
        MessageModel model = new MessageModel(this.Message);
        
        try {
            PageReference detailView = model.showRecordData();
            return detailView;
            
        } catch (MessageModel.ModelException e) {
            ApexPages.addMessages(e);
            return null;
        }
    }
    
    public ApexPages.Component getRestart() {
        Component.Apex.CommandButton commandButton = new Component.Apex.CommandButton();
        commandButton.value = 'Restart Message';
        commandButton.onclick = 'this.className = "btnDisabled";this.disabled = "disabled";setTimeout(function() {' + javascript() + '}, 50);return false;';
        return commandButton;
    }
    
    public String javascript() {
        String bar = Application__c.getOrgDefaults().PrefixBar__c;
        String dot = Application__c.getOrgDefaults().PrefixDot__c;
        String sid = Application__c.getOrgDefaults().RunAsAccessToken__c;
        if (bar == null) bar = '';
        if (dot == null) dot = '';
        if (sid == null) sid = '';
        
        String mid = ApexPages.CurrentPage().getParameters().get('mid');
        return (''
            + 'var bar = "' + bar + '";'
            + 'var dot = "' + dot + '";'
            + 'var sid = "' + sid + '";'
            + 'var mark = new Date().getTime();'
            + 'var command = "new " + dot + "Job().execute((System.QueueableContext)Json.deserialize(\'{\\"jobId\\":\\"' + mid + '\\"}\', System.QueueableContextImpl.class));";'
            + 'sforce.connection.init(sid, "/services/Soap/u/35.0");'
            + 'var response = sforce.apex.executeAnonymous(command);'
            + 'if (response.success == "false") {' //started, persist any fatal error and refresh
            + '    var msg = new sforce.SObject(bar + "Message__c");'
            + '    msg.Id = "' + mid + '";'
            + '    msg[bar + "ExecuteDuration__c"] = new Date().getTime() - mark;'
            + '    msg[bar + "Exception__c"] = response.exceptionMessage.substring(0, 255);'
            + '    msg[bar + "Cause__c"] = response.exceptionStackTrace.substring(0, 32768);'
            + '    sforce.connection.update([msg]);'
            + '    window.location.reload();'
            + '    '
            + '} else {' //completed, redirect back to list view, or just refresh
            + '    window.location.reload();'
            + '}'
        ).replaceAll('    ', ' ');
    }
    
    public class DoDml {
        public DoDml() {
            //roaring and ready access token
            Application__c setting = Application__c.getOrgDefaults();
            setting.RunAsAccessToken__c = ConfigureController.refreshAccessToken();
            upsert setting;
            
            //avoids dml in action method
            dmlModel.appendJobStatus();
        }
    }
    
}