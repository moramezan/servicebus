public with sharing class ProcessExtensionCustomize {
    
    private ApexPages.StandardController controller;
    
    public ProcessExtensionCustomize(ApexPages.StandardController controller) {
        if (!Test.isRunningTest()) controller.addFields(new List<String>{SObjectType.Process__c.fields.Name.Name});
        this.controller = controller;
    }
    
    public System.PageReference initCustom() {
        try {
            //customizable processes redirect to setting tab
            Process__c process = (Process__c)this.controller.getRecord();
            String className = process.Name; // TODO (Apex Class Name )
            String customizable = (String) Utility.meta(className).get('customizable');
            SObject setting = (SObject)Type.forName(customizable).newInstance();
            String prefix = setting.getSObjectType().getDescribe().getKeyPrefix();
            return new System.PageReference('/' + prefix + '/o');
        } catch (Exception e) {
            //uncustomizable process redirects back to process detail
            Process__c process = (Process__c)this.controller.getRecord();
            return new ApexPages.StandardController(process).view();
        }
    }
    
}