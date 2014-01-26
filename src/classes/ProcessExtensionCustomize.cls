public with sharing class ProcessExtensionCustomize {
    
    private ApexPages.StandardController controller;
    
    public ProcessExtensionCustomize(ApexPages.StandardController controller) {
        if (!Test.isRunningTest()) controller.addFields(new List<String>{
            SObjectType.Process__c.fields.Name.Name,
            SObjectType.Process__c.fields.Customizable__c.Name
        });
        this.controller = controller;
    }
    
    public System.PageReference initCustom() {
        Process__c process = (Process__c)this.controller.getRecord();
        PageReference pageReference = new ApexPages.StandardController(process).view();
        String customizable  = process.Customizable__c;
        if (!String.isBlank(customizable)) {
            //customizable processes redirect to setting tab
            try {
                SObject setting = (SObject)Type.forName(customizable).newInstance();
                String prefix = setting.getSObjectType().getDescribe().getKeyPrefix();
                pageReference = new ApexPages.PageReference('/' + prefix + '/o');
            } catch (Exception e) {
                //
            }   
        }
        
        return pageReference;
    }
    
}