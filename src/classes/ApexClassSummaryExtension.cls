public with sharing class ApexClassSummaryExtension {
    
    ApexPages.StandardController controller;
    ApexClassModel model;
    
    public ApexClassModel.Summary Summary {get; set;}
    public String FullyQualifiedClassName {get; set;}
    
    public ApexClassSummaryExtension(ApexPages.StandardController controller) {
        this.controller = controller;
        this.countRoutedMessages();
    }
    
    public Integer RoutedMessages {get; set;}
    
    /**
     * #768 this is used to indicate there is work ongoing
     * by displaying a twirly alongside the count of messages
     * that are flowing through this sequence.
     */
    public void countRoutedMessages() {
        this.RoutedMessages = 0;
    }
    
    public PageReference doInit() {
        try {
            this.model = ApexClassModel.fromId(controller.getId());
            this.Summary = new ApexClassModel.Summary(model.Reflector);
            this.FullyQualifiedClassName = model.Reflector.getName();
            return this.model.showHelpUrl();
            
        } catch (ApexClassModel.ModelException e) {
            ApexPages.addMessages(e);
            return null;
        }
    }
    
    /**
     * #1096
     */
    public Id JobId {get; set;}
    
    public void doEnqueue() {
        this.JobId = this.model.enqueueTestMessage();
    }
    
}