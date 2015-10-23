public with sharing class SequenceDiscardExtension {
    
    SequenceSetModel model;
    ApexPages.StandardSetController controller;
    
    public SequenceDiscardExtension(ApexPages.StandardSetController controller) {
        this.controller = controller;
    }

    public PageReference doDiscard() {
        try {
            SequenceSetModel.discardDraft();
            return new ApexPages.Action('{!List}').invoke();
            
        } catch (Exception e) {
            ApexPages.addMessages(e);
            return null;
            
        }
    }
    
}