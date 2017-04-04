public with sharing class SequenceNewExtension {
    
    ApexPages.StandardController controller;
    
    public SequenceNewExtension(ApexPages.StandardController controller) {
        this.controller = controller;
    }
    
    public Integer getDraftVersion() {
        return SequenceSetModel.draftVersion();
    }
    
    public void doValidate() {
        Sequence__c sequence = new Sequence__c(Name = 'SequenceNewExtension');
        new SequenceSetModel(new List<Sequence__c>{sequence}).inhibitInsertWithoutCheckout();
    }
    
}