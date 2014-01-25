@isTest private class ProcessGenerateExtensionTest {
    
    static testMethod void testGetAsyncApexJob() {
        //arrange
        ProcessGenerateExtension.jobs = new List<AsyncApexJob>{new AsyncApexJob(Id = '707000000000000AAA')};
        ApexPages.StandardSetController controller = new ApexPages.StandardSetController(new List<Process__c>());
        ProcessGenerateExtension extension = new ProcessGenerateExtension(controller);
        Test.startTest();
        ProcessRefreshBatch batch = new ProcessRefreshBatch();
        batch.query = 'SELECT Id, NamespacePrefix, Name FROM ApexClass WHERE Name = \'Terminate\' ORDER BY Name ASC LIMIT 1';
        Database.executeBatch(batch, 1);
        Test.stopTest();
        
        //act
        AsyncApexJob job = extension.getAsyncApexJob();
        
        //assert
        Id expectedId = '707000000000000AAA';
        Id actualId = job.Id;
        System.assertEquals(expectedId, actualId);
    }
    
    static testMethod void testReadAsyncApexJobs() {
        //arrange
        ProcessGenerateExtension.jobs = new List<AsyncApexJob>{new AsyncApexJob(Id = '707000000000000AAA')};
        
        //act
        List<AsyncApexJob> jobs = ProcessGenerateExtension.readAsyncApexJobs('707000000000000AAA');
        
        //assert
        Id expectedId = '707000000000000AAA';
        Id actualId = jobs[0].Id;
        System.assertEquals(expectedId, actualId);
    }
    
    static testMethod void testReadProcesses() {
        //arrange
        ProcessGenerateExtension.processes = new List<Process__c>{new Process__c(Name = 'Test')};
        
        //act
        List<Process__c> processes = ProcessGenerateExtension.readProcesses(System.now());
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = processes.size();
        System.assertEquals(expectedSize, actualSize);
        
        String expectedName = 'Test';
        String actualName = processes[0].Name;
        System.assertEquals(expectedName, actualName);
    }
    
    static testMethod void testNotRedirectedWhenViewingJob() {
        PageReference generate = Page.ProcessGenerate;
        generate.getParameters().put('asyncApexJobId', '707000000000000AAA');
        Test.setCurrentPage(generate);
        //generate.doRedirect
    }
    
}