@IsTest private class AsyncApexJobsTest {
    
    static testmethod void testAbortJobs() {
        
        //before
        Integer expectedBefore = 0;
        Integer actualBefore = [SELECT COUNT() FROM AsyncApexJob];
        System.assertEquals(expectedBefore, actualBefore);
        
        Test.startTest();
        
        Id one = Database.executeBatch(new BatchBrokerImplementation(), 1);
        Id two = Database.executeBatch(new BatchBrokerImplementation(), 1);
        AsyncApexJobs asyncApexJobs = new AsyncApexJobs(new List<AsyncApexJob>{
            new AsyncApexJob(Id = one),
            new AsyncApexJob(Id = two)
        });
        
        //during
        Integer expectedRunning = 2;
        Integer actualRunning = [SELECT COUNT() FROM AsyncApexJob];
        System.assertEquals(expectedRunning, actualRunning);
        
        asyncApexJobs.abort();
        
        Test.stopTest();

        //after
        Integer expectedStopped = 2;
        Integer actualStopped = [SELECT COUNT() FROM AsyncApexJob WHERE Status = 'Aborted'];
        System.assertEquals(expectedStopped, actualStopped);
    }
    
    static testmethod void testRunOneOnlyRunsJobOnce() {
        Test.startTest();
        AsyncApexJobs one = AsyncApexJobs.runOne(BatchBrokerImplementation.class, 1);
        AsyncApexJobs two = AsyncApexJobs.runOne(BatchBrokerImplementation.class, 1);
        Test.stopTest();
        
        Integer expectedRunning = 1;
        Integer actualRunning = [SELECT COUNT() FROM AsyncApexJob];
        System.assertEquals(expectedRunning, actualRunning);
        
        String serializedOne = System.Json.serializePretty(one.getSObjects()[0].Id);
        String serializedTwo = System.Json.serializePretty(two.getSObjects()[0].Id);
        System.assertEquals(serializedOne, serializedTwo);
    }

}