public with sharing class ConfirmItemConfirmExtension {
    
    private ApexPages.StandardController controller;
    
    public ConfirmItemConfirmExtension(ApexPages.StandardController controller) {
        this.controller = controller;
    }
    
    public PageReference doConfirm() {
        Id confirmItemId = controller.getId();
        ConfirmItem__c confirmItem = (ConfirmItem__c)SalesforceObject.getById(confirmItemId);
        
        confirmItem.Confirm__c = true;
        update confirmItem;
        
        ConfirmConfig__c confirmConfig = new ConfirmConfig__c(Id = confirmItem.ConfirmConfig__c);
        return new ApexPages.StandardController(confirmConfig).view();
    }

}