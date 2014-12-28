public with sharing class MessageDataExtension {
    
    private ApexPages.StandardController controller;
    
    public MessageDataExtension(ApexPages.StandardController controller) {
        this.controller = controller;
    }
    
    public PageReference doRedirect() {
        Message__c message = (Message__c)SalesforceObject.getById(this.controller.getId());
        Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(message.Parameters__c);
        
        try {
            Id dataId = (Id)parameters.get('esb__Id');
            SObject dataObject = SalesforceObject.getById(dataId);
            return new ApexPages.StandardController(dataObject).view();
        } catch (Exception e) {
            return new ApexPages.StandardController(this.controller.getRecord()).view();
        }
    }

}