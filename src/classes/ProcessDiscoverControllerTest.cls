@isTest private class ProcessDiscoverControllerTest {
    
    static testMethod void testGetAsyncApexJob() {
        //arrange
        ProcessDiscoverController.jobs = new List<AsyncApexJob>{new AsyncApexJob(Id = '707000000000000AAA')};
        ProcessDiscoverController extension = new ProcessDiscoverController();
        Test.startTest();
        ProcessDiscoverBatch.classes = [
            SELECT Id, Name, NamespacePrefix
            FROM ApexClass
            WHERE Name = 'Terminate'
            ORDER BY Name ASC
            LIMIT 1
        ];
        ProcessDiscoverBatch batch = new ProcessDiscoverBatch();
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
        ProcessDiscoverController.jobs = new List<AsyncApexJob>{new AsyncApexJob(Id = '707000000000000AAA')};
        
        //act
        List<AsyncApexJob> jobs = ProcessDiscoverController.readAsyncApexJobs('707000000000000AAA');
        
        //assert
        Id expectedId = '707000000000000AAA';
        Id actualId = jobs[0].Id;
        System.assertEquals(expectedId, actualId);
    }
    
    static testMethod void testReadProcesses() {
        //arrange
        ProcessDiscoverController.processes = new List<Process__c>{new Process__c(Name = 'Test')};
        
        //act
        List<Process__c> processes = ProcessDiscoverController.readProcesses(System.now());
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = processes.size();
        System.assertEquals(expectedSize, actualSize);
        
        String expectedName = 'Test';
        String actualName = processes[0].Name;
        System.assertEquals(expectedName, actualName);
    }
    
}