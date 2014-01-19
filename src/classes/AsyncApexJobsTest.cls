@isTest private class AsyncApexJobsTest {
    
    static testMethod void testAbortJobs() {
        
        //before
        Integer expectedBefore = 0;
        Integer actualBefore = [SELECT COUNT() FROM AsyncApexJob];
        System.assertEquals(expectedBefore, actualBefore);
        
        Test.startTest();
        
        Id one = Database.executeBatch(new Broker(), 1);
        Id two = Database.executeBatch(new Broker(), 1);
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
    
    static testMethod void testRunOneOnlyRunsJobOnce() {
        Test.startTest();
        AsyncApexJobs one = AsyncApexJobs.runOne(Broker.class, 1);
        AsyncApexJobs two = AsyncApexJobs.runOne(Broker.class, 1);
        Test.stopTest();
        
        Integer expectedRunning = 1;
        Integer actualRunning = [SELECT COUNT() FROM AsyncApexJob];
        System.assertEquals(expectedRunning, actualRunning);
        
        String serializedOne = System.Json.serializePretty(one);
        String serializedTwo = System.Json.serializePretty(two);
        System.assertEquals(serializedOne, serializedTwo);
    }

}