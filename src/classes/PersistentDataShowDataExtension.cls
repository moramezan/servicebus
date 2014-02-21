public class PersistentDataShowDataExtension {
    
    private ApexPages.StandardController controller;
    
    public PersistentDataShowDataExtension(ApexPages.StandardController controller) {
        this.controller = controller;
    }
    
    public PageReference doRedirect() {
        PersistentData__c persistentData = (PersistentData__c)SalesforceObject.getById(this.controller.getId());
        Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(persistentData.Parameters__c);
        
        try {
            Id dataId = (Id)parameters.get('id');
            SObject dataObject = SalesforceObject.getById(dataId);
            return new ApexPages.StandardController(dataObject).view();
        } catch (Exception e) {
            return new ApexPages.StandardController(this.controller.getRecord()).view();
        }
    }

}