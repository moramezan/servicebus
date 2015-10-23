public with sharing class SequenceCheckoutExtension {
    
    SequenceSetModel model;
    ApexPages.StandardSetController controller;
    
    public SequenceCheckoutExtension(ApexPages.StandardSetController controller) {
        this.controller = controller;
    }
    
    public PageReference doCheckout() {
        try {
            SequenceSetModel.checkoutDraft();
            return new ApexPages.Action('{!List}').invoke();
            
        } catch (Exception e) {
            ApexPages.addMessages(e);
            return null;
            
        }
    }
    
}