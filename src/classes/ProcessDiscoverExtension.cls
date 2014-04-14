/**
 * This class is WITHOUT SHARING to ensure any running user context can access ApexClass etc
 * See http://salesforce.stackexchange.com/q/258/320 and http://salesforce.stackexchange.com/q/32607/320
 */
public without sharing class ProcessDiscoverExtension {
    
    private ApexPages.StandardSetController controller;
    
    public ProcessDiscoverExtension(ApexPages.StandardSetController controller) {
        this.controller = controller;
    }
    
    public String getRetURL() {
        if (ApexPages.currentPage().getParameters().get('retURL') == null) {
            //return to list view, could try ApexPages.currentPage().getHeaders().get('Referer');
            String prefix = SObjectType.Process__c.KeyPrefix;
            return new ApexPages.PageReference('/' + prefix).getUrl();
        } else {
            //return to calling page, eg the SequenceBuilder if it sent you here
            return ApexPages.currentPage().getParameters().get('retURL');
        }
    }
    
    public AsyncApexJob getAsyncApexJob() {
        Id asyncApexJobId = ApexPages.currentPage().getParameters().get('asyncApexJobId');
        return readAsyncApexJobs(asyncApexJobId)[0];
    }
    
    public System.PageReference doRedirect() {
        if (ApexPages.currentPage().getParameters().get('asyncApexJobId') == null) {
            //someone tried to view the page... start the batch job and show it
            AsyncApexJobs jobs = AsyncApexJobs.runOne(ProcessDiscoverBatch.class, 1);
            PageReference processDiscover = Page.ProcessDiscover;
            processDiscover.getParameters().put('asyncApexJobId', jobs.getSObjects()[0].Id);
            processDiscover.getParameters().put('retURL', ApexPages.currentPage().getParameters().get('retURL'));
            processDiscover.setRedirect(true);
            return processDiscover;
        } else {
            //we are trying to show the batch job... just display the page
            return null;
        }
    }
    
    @testVisible static private List<Process__c> processes;
    @RemoteAction static public List<Process__c> readProcesses(DateTime lastModifiedDate) {
        return processes != null ? processes : [
            SELECT Id, Name, Description__c, Tag__c, Icon__c, FullyQualifiedClassName__c
            FROM Process__c
            WHERE LastModifiedDate > :lastModifiedDate
            ORDER BY Name DESC //per #240 so the new ones don't run off the bottom of the screen
        ];
    }
    
    @testVisible static private List<AsyncApexJob> jobs;
    @RemoteAction static public List<AsyncApexJob> readAsyncApexJobs(Id asyncApexJobId) {
        return jobs != null ? jobs : new List<AsyncApexJob>{(AsyncApexJob)SalesforceObject.getById(asyncApexJobId)};
    }

}