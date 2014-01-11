public with sharing class ProcessExtensionRefresh {
    
    //find any pending instances of ProcessRefreshBatch
    @testVisible private List<AsyncApexJob> refreshJobs = [
        SELECT Id
        FROM AsyncApexJob
        WHERE ApexClass.Name = 'ProcessRefreshBatch'
        AND JobType IN ('BatchApex', 'ScheduledApex')
        AND Status IN ('Queued', 'Processing', 'Preparing')
    ];
    
    //find all batch/scheduled jobs which have not finished
    @testVisible private List<AsyncApexJob> otherJobs = [
        SELECT Id
        FROM AsyncApexJob
        WHERE JobType IN ('BatchApex', 'ScheduledApex')
        AND Status IN ('Processing', 'Preparing')
    ];
    
    public ProcessExtensionRefresh(ApexPages.StandardSetController controller) {
        //
    }
    
    public System.PageReference doRedirect() {
        String prefix = Process__c.getSObjectType().getDescribe().getKeyPrefix();
        System.PageReference tab = new System.PageReference('/' + prefix);
        
        if (this.otherJobs.size() >= 5) {
            //no slot available
            tab.getParameters().put('error', 'insufficient_slots');
            return tab;
        }
        
        if (!this.refreshJobs.isEmpty()) {
            //is running, stop here
            tab.getParameters().put('error', 'already_running');
            return tab;
        }
        
        Database.executeBatch(new ProcessRefreshBatch(), 1);
        tab.getParameters().put('running', 'ok');
        return tab;
    }
    
}