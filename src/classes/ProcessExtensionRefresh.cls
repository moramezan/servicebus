public with sharing class ProcessExtensionRefresh {
    
    public ProcessExtensionRefresh(ApexPages.StandardSetController controller) {
        //
    }
    
    public System.PageReference doRedirect() {
        AsyncApexJobs jobs = AsyncApexJobs.runOne(ProcessRefreshBatch.class, 1);
        System.PageReference tab = new System.PageReference('/' + Schema.SObjectType.Process__c.KeyPrefix);
        tab.getParameters().put('id', jobs.getSObjects()[0].Id);
        return tab;
    }
    
}