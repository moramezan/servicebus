public with sharing class SequenceCommitExtension {
    
    SequenceSetModel model;
    ApexPages.StandardSetController controller;
    
    public SequenceCommitExtension(ApexPages.StandardSetController controller) {
        this.controller = controller;
    }
    
    public PageReference doCommit() {
        try {
            SequenceSetModel.commitDraft();
            return new ApexPages.Action('{!List}').invoke();
            
        } catch (Exception e) {
            ApexPages.addMessages(e);
            return null;
            
        }
    }
    
}