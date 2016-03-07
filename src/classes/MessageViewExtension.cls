public with sharing class MessageViewExtension {
    
    Id mid;
    ApexPages.StandardController controller;
    static Application__c application = Application__c.getOrgDefaults();

    @RemoteAction static public void handleRestart(Id messageId, Long duration, String exceptions, String cause) {
        //execanon results
        update new Message__c(
            Id = messageId,
            Status__c = 'Started',
            ExecuteDuration__c = duration,
            Exception__c = MessageModel.scrubException(exceptions),
            Cause__c = MessageModel.scrubCause(cause)
        );
    }
    
    public MessageViewExtension(ApexPages.StandardController controller) {
        //need to redirect, nothing to do
        this.controller = controller;
        if (this.controller.getId() != null) return;
        
        //grab latest access token
        this.mid = ApexPages.currentPage().getParameters().get('mid');
        if (!Test.isRunningTest()) application.RunAsAccessToken__c = ConfigureController.refreshAccessToken();
    }
    
    public ApexClassModel.Definition getDefinition() {
        try {
            Message__c message = (Message__c)ApexDomain.getById(this.mid);
            return ApexClassModel.fromRoute(message.Route__c).getDefinition();
        } catch (Exception e) {
            ApexPages.addMessages(e);
            return null;
        }
    }
    
    public Message__c getMessage() {
        return (Message__c)ApexDomain.getById(this.mid);
    }
    
    public List<Message__c> getChildren() {
        return [
            SELECT Id, Name, CreatedDate, Status__c, Route__c, ExecuteDuration__c, Exception__c
            FROM Message__c
            WHERE ParentId__c = :this.mid
            ALL ROWS
        ];
    }
    
    public PageReference doInit() {
        
        if (this.controller.getId() != null) {
            //redirect to mid
            PageReference redirect = Page.MessageView;
            redirect.getParameters().put('mid', this.controller.getId());
            redirect.setredirect(true); //prevents internal error
            return redirect;
        }
        
        try {
            Type.forName(DoDml.class.getName()).newInstance();
        } catch (Exception e) {
            ApexPages.addMessages(e);
        }
        
        return null;
    }
    
    public PageReference showService() {
        try {
            return MessageModel.fromId(this.mid).showService();
        } catch (MessageModel.ModelException e) {
            ApexPages.addMessages(e);
            return null;
        }
    }
    
    public PageReference showData() {
        try {
            return MessageModel.fromId(this.mid).showRecordData();
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
    
    /**
     * we cannot just GET the access token, because the CACHED custom
     * setting is obviously STALE in the same execution context, so we
     * must pull it straight off the refresh happening in constructor
     */
    public String javascript() {
        String sid = application.RunAsAccessToken__c;
        String bar = Application__c.getOrgDefaults().PrefixBar__c;
        String dot = Application__c.getOrgDefaults().PrefixDot__c;
        if (sid == null) sid = '';
        if (bar == null) bar = '';
        if (dot == null) dot = '';
        
        Map<String,Object> parameters = new Map<String,Object>{'ToService' => 'Services.RestartMessageId', 'RecordId' => this.mid};
        return (''
            + 'var mid = "' + mid + '";'
            + 'var bar = "' + bar + '";'
            + 'var sid = "' + sid + '";'
            + 'var mark = new Date().getTime();'
            + 'var command = \'new ' + Enqueue.class.getName() + '().invoke(new Process.PluginRequest((Map<String,Object>)Json.deserializeUntyped(\\\'' + Json.serialize(parameters) + '\\\')));\';'
            + 'sforce.connection.init(sid, "/services/Soap/u/36.0");'
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
        ).replaceAll('    ', '');
    }
    
    public class DoDml {
        public DoDml() {
            upsert application;
            Id mid = ApexPages.currentPage().getParameters().get('mid');
            MessageModel.fromId(mid).healExtendedStatus();
        }
    }
    
}