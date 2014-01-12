@isTest public class ProcessExtensionRefreshTest {
    
    static testMethod void testStartRefreshJob() {
        //normal case where there are slots available and the job is not running
        List<Process__c> processes = new List<Process__c>();
        ApexPages.StandardSetController controller = new ApexPages.StandardSetController(processes);
        ProcessExtensionRefresh extension = new ProcessExtensionRefresh(controller);
        
        Test.startTest();
        System.PageReference tab = extension.doRedirect();
        Test.stopTest();
        
        System.assert(tab.getUrl().contains(Schema.SObjectType.Process__c.KeyPrefix));
    }
    
}