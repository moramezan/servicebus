public with sharing class ConfirmItemDenyExtension {
    
    private ApexPages.StandardController controller;
    
    public ConfirmItemDenyExtension(ApexPages.StandardController controller) {
        this.controller = controller;
    }
    
    public PageReference doDeny() {
        Id confirmItemId = controller.getId();
        ConfirmItem__c confirmItem = (ConfirmItem__c)SalesforceObject.getById(confirmItemId);
        
        confirmItem.Deny__c = true;
        update confirmItem;
        
        ConfirmConfig__c confirmConfig = new ConfirmConfig__c(Id = confirmItem.ConfirmConfig__c);
        return new ApexPages.StandardController(confirmConfig).view();
    }

}