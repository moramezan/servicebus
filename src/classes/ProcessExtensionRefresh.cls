public with sharing class ProcessExtensionRefresh {
    
    public ProcessExtensionRefresh(ApexPages.StandardSetController controller) {
        //
    }
    
    public System.PageReference doRedirect() {
        AsyncApexJobs.runOne(ProcessRefreshBatch.class, 1);
        return new System.PageReference('/' + Schema.SObjectType.Process__c.KeyPrefix);
    }
    
}