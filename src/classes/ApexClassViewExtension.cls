public with sharing class ApexClassViewExtension {
    
    ApexPages.StandardController controller;
    ApexClassModel model;
    
    public ApexClassModel.Definition Definition {get; set;}
    public String FullyQualifiedClassName {get; set;}
    
    public ApexClassViewExtension(ApexPages.StandardController controller) {
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
            this.FullyQualifiedClassName = model.Reflector.getName();
            if (Test.isRunningTest()) this.Definition = new ApexClassModel.Definition(model.Reflector); //unit tests skip cache
            else if (!Test.isRunningTest()) this.Definition = ApexClassSetModel.loadCache().get(this.FullyQualifiedClassName);
            return this.model.showHelpUrl();
            
        } catch (ApexClassModel.ModelException e) {
            e.setMessage('ApexClassViewExtension.doInit: ' + e.getMessage());
            ApexPages.addMessages(e);
            return null;
        }
    }
    
    public List<Step__c> getSteps() {
        return [
            SELECT Id, Name, Version__c, Sequence__c, Position__c, ConfigId__c, ConfigName__c
            FROM Step__c
            WHERE ApexTypeName__c = :this.FullyQualifiedClassName
            AND Version__c = :Application__c.getOrgDefaults().RouterVersion__c
            ORDER BY Name ASC
        ];
    }
    
    /**
     * #1096
     */
    public Id JobId {get; set;}
    public Id MessageId {get; set;}

    public void doEnqueue() {
        this.JobId = this.model.enqueueTestMessage();
        Message__c message = [SELECT Id FROM Message__c WHERE JobId__c = :this.JobId];
        this.MessageId = message.Id;
    }
    
}