public with sharing class SequenceCommitExtension implements Database.Batchable<Sobject> {
    
    SequenceSetModel model;
    ApexPages.StandardSetController controller;
    Id asyncApexJobId = ApexPages.CurrentPage().getParameters().get('id');
    
    public SequenceCommitExtension(ApexPages.StandardSetController controller) {
        this.controller = controller;
    }
    
    public PageReference doCommit() {
        
        if (this.asyncApexJobId != null) {
            //we are trying to show the batch job... just display the page
            return null;
        }
        
        try {
            //someone tried to view the page... start the batch job and show it
            this.asyncApexJobId = SequenceSetModel.commitDraft();
            PageReference currentPage = ApexPages.CurrentPage();
            currentPage.getParameters().put('id', this.asyncApexJobId);
            currentPage.setRedirect(true);
            return currentPage;
            
        } catch (SequenceSetModel.ModelException e) {
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
    public SequenceCommitExtension() {
        //
    }
    
    public Database.QueryLocator start(Database.BatchableContext context) {
        //find current draft version
        return SequenceSetModel.locateDraftSteps();
    }
    
    public void execute(Database.BatchableContext context, List<Step__c> steps) {
        //commits each step
        StepModel.fromId(steps[0].Id).commits();
    }
    
    public void finish(Database.BatchableContext context) {
        //trashes sequence handles
        SequenceSetModel.hideSequences();
    }
    
}