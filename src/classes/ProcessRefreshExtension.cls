public with sharing class ProcessRefreshExtension {
    
    private ApexPages.StandardController controller;
    @TestVisible static private Process__c process;
    
    public ProcessRefreshExtension(ApexPages.StandardController controller) {
        this.controller = controller;
    }
    
    public PageReference doRefresh() {
        try {
            process = (Process__c)ApexDomain.getById(this.controller.getId());
            Type reflector = Type.forName(process.FullyQualifiedClassName__c);
            
            process = ProcessModel.fromType(reflector);
            Type.forName(DoDml.class.getName()).newInstance();
        } catch (Exception e) {
            ApexPages.addMessages(e);
            return null;
        }
        
        //back to detail page
        return this.controller.view();
    }
    
    public class DoDml {
        public DoDml() {
            upsert process FullyQualifiedClassName__c;
        }
    }

}