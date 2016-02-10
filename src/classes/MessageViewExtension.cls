public with sharing class MessageViewExtension {
    
    static MessageModel dmlModel;
    ApexPages.StandardController controller;
    public Message__c Message {get; set;}
    public List<Message__c> Children {get; set;}
    public ApexClassModel.Definition Definition {get; set;}
    
    public MessageViewExtension(ApexPages.StandardController controller) {
        this.controller = controller;
    }
    
    @RemoteAction static public void handleRestart(Id messageId, Long duration, String exceptions, String cause) {
        //execanon results
        update new Message__c(
            Id = messageId,
            Status__c = 'Started',
            ExecuteDuration__c = duration,
            Exception__c = exceptions.abbreviate(SObjectType.Message__c.Fields.Exception__c.Length),
            Cause__c = cause.replaceAll('[\r]?\n', '\r\n').abbreviate(SObjectType.Message__c.Fields.Cause__c.Length)
        );
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
            SELECT Id, Name, CreatedDate, Status__c, Route__c, ExecuteDuration__c, Exception__c, Cause__c, Event__c, JobId__c, ParentId__c, Slot__c
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
            //resolve class name
            String apexTypeName = this.Message.Route__c;
            Step__c step = Step__c.getValues(this.Message.Route__c);
            if (step != null) apexTypeName = step.ApexTypeName__c;
            
            //unit tests skip cache
            if (Test.isRunningTest()) this.Definition = new ApexClassModel.Definition(Type.forName(apexTypeName));
            else if (!Test.isRunningTest()) this.Definition = ApexClassSetModel.loadCache().get(apexTypeName);
            
        } catch (Exception e) {
            ApexPages.addMessages(e);
        }
        
        try {
            dmlModel = new MessageModel(this.Message);
            Type.forName(DoDml.class.getName()).newInstance();
        } catch (Exception e) {
            ApexPages.addMessages(e);
        }
        
        return null;
    }
    
    public PageReference showService() {
        MessageModel model = new MessageModel(this.Message);
        
        try {
            PageReference detailView = model.showService();
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
        Map<String,Object> parameters = new Map<String,Object>{'ToService' => 'Services.RestartMessageId', 'RecordId' => mid};
        return (''
            + 'var mid = "' + mid + '";'
            + 'var bar = "' + bar + '";'
            + 'var sid = "' + sid + '";'
            + 'var mark = new Date().getTime();'
            + 'var command = \'new ' + Enqueue.class.getName() + '().invoke(new Process.PluginRequest((Map<String,Object>)Json.deserializeUntyped(\\\'' + Json.serialize(parameters) + '\\\')));\';'
            + 'sforce.connection.init(sid, "/services/Soap/u/35.0");'
            + 'var response = sforce.apex.executeAnonymous(command);'
            + 'if (response.success == "false") {' //started, persist any fatal error and refresh
            + '    Visualforce.remoting.Manager.invokeAction('
            + '        $RemoteAction.MessageViewExtension.handleRestart,'
            + '        mid,'
            + '        new Date().getTime() - mark,'
            + '        response.exceptionMessage,'
            + '        response.exceptionStackTrace,'
            + '        function() {window.location.reload();},'
            + '        {}'
            + '    );'
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
            dmlModel.healExtendedStatus();
        }
    }
    
}