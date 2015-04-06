public with sharing class MessageDataExtension {
    
    private ApexPages.StandardController controller;
    
    public MessageDataExtension(ApexPages.StandardController controller) {
        this.controller = controller;
    }
    
    public PageReference doRedirect() {
        try {
        Message__c message = (Message__c)ApexDomain.getById(this.controller.getId());
        Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(message.Event__c);
        
        try {
            Id dataId = (Id)parameters.get('esb__Id');
            SObject dataObject = ApexDomain.getById(dataId);
            return new ApexPages.StandardController(dataObject).view();
        } catch (Exception e) {
            return new ApexPages.StandardController(this.controller.getRecord()).view();
        }
        } catch (Exception e) {
            ApexPages.addMessages(e);
            return null;
        }
    }

}