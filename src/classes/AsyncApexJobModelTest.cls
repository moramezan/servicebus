@IsTest private class AsyncApexJobModelTest {
    
    static testmethod void testAbortJobs() {
        
        //before
        Integer expectedBefore = 0;
        Integer actualBefore = [SELECT COUNT() FROM AsyncApexJob];
        System.assertEquals(expectedBefore, actualBefore);
        
        Test.startTest();
        
        Id one = Database.executeBatch(new ProcessDiscoverBatch(), 1);
        AsyncApexJobModel asyncApexJob = new AsyncApexJobModel(new AsyncApexJob(Id = one));
        
        //during
        Integer expectedRunning = 1;
        Integer actualRunning = [SELECT COUNT() FROM AsyncApexJob];
        System.assertEquals(expectedRunning, actualRunning);
        
        asyncApexJob.abort();
        
        Test.stopTest();

        //after
        Integer expectedStopped = 1;
        Integer actualStopped = [SELECT COUNT() FROM AsyncApexJob WHERE Status = 'Aborted'];
        System.assertEquals(expectedStopped, actualStopped);
    }
    
    static testmethod void testRunOneOnlyRunsJobOnce() {
        Test.startTest();
        ProcessDiscoverBatch.classes = new List<ApexClass>();
        AsyncApexJobModel one = AsyncApexJobModel.runOne(ProcessDiscoverBatch.class, 1);
        AsyncApexJobModel two = AsyncApexJobModel.runOne(ProcessDiscoverBatch.class, 1);
        Test.stopTest();
        
        Integer expectedRunning = 1;
        Integer actualRunning = [SELECT COUNT() FROM AsyncApexJob];
        System.assertEquals(expectedRunning, actualRunning);
        
        String serializedOne = System.Json.serializePretty(one.getRecord().Id);
        String serializedTwo = System.Json.serializePretty(two.getRecord().Id);
        System.assertEquals(serializedOne, serializedTwo);
    }

}