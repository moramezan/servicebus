public with sharing class SequenceCheckoutExtension implements Database.Batchable<Sobject>, Database.Stateful {
    
    SequenceSetModel model;
    ApexPages.StandardSetController controller;
    Id asyncApexJobId = ApexPages.CurrentPage().getParameters().get('id');
    
    public SequenceCheckoutExtension(ApexPages.StandardSetController controller) {
        this.controller = controller;
    }
    
    public PageReference doCheckout() {
        
        if (this.asyncApexJobId != null) {
            //we are trying to show the batch job... just display the page
            return null;
        }
        
        try {
            //someone tried to view the page... start the batch job and show it
            this.asyncApexJobId = SequenceSetModel.checkoutDraft();
            PageReference currentPage = ApexPages.CurrentPage();
            currentPage.getParameters().put('id', this.asyncApexJobId);
            currentPage.setRedirect(true);
            return currentPage;
            
        } catch (SequenceSetModel.ModelException e) {
            e.setMessage('SequenceCheckoutExtension.doCheckout: ' + e.getMessage());
            ApexPages.addMessages(e);
            return null;
        }
    }
    
    public AsyncApexJob getAsyncApexJob() {
        return (AsyncApexJob)ApexDomain.getById(this.asyncApexJobId);
    }
    
    @RemoteAction static public List<Step__c> ReadRecords(Id asyncApexJobId) {
        return new ApexPages.StandardSetController(SequenceSetModel.locateDraftSteps()).getRecords();
    }
    
    @RemoteAction static public List<AsyncApexJob> ReadAsyncApexJobs(Id asyncApexJobId) {
        return ApexDomain.get([SELECT Id FROM AsyncApexJob WHERE Id = :asyncApexJobId]);
    }
    
    /**
     * Unfortunately, Database.Batchable has to be a top-level class.
     * Otherwise would have put this guy as an inner class of the set model.
     *
     * So for now it's baked into the controller extension.
     * We can always move it, but he almost belongs here :)
     * All his logic stays in the model, this just iterates.
     */
    public SequenceCheckoutExtension() {
        //
    }
    
    public List<Step__c> newSteps = new List<Step__c>();
    
    public Database.QueryLocator start(Database.BatchableContext context) {
        //find latest live version
        return SequenceSetModel.locateLiveSteps();
    }
    
    public void execute(Database.BatchableContext context, List<Step__c> scopes) {
        //copies each config to database, copies each step to memory
        StepModel.fromId(scopes[0].Id).checkout(this.newSteps);
    }
    
    public void finish(Database.BatchableContext context) {
        //#1171 isolate checkout
        insert this.newSteps;
        
        //recreates sequence handles
        SequenceSetModel.showSequences();
        
        //unflag mutex per #1178
        SequenceSetModel.routerNotBusy();
    }
    
}