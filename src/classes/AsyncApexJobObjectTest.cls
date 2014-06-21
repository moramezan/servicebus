@IsTest private class AsyncApexJobObjectTest {
    
    static testmethod void testAbortJobs() {
        
        //before
        Integer expectedBefore = 0;
        Integer actualBefore = [SELECT COUNT() FROM AsyncApexJob];
        System.assertEquals(expectedBefore, actualBefore);
        
        Test.startTest();
        
        Id one = Database.executeBatch(new BatchBrokerImplementation(), 1);
        AsyncApexJobObject asyncApexJob = new AsyncApexJobObject(new AsyncApexJob(Id = one));
        
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
        AsyncApexJobObject one = AsyncApexJobObject.runOne(BatchBrokerImplementation.class, 1);
        AsyncApexJobObject two = AsyncApexJobObject.runOne(BatchBrokerImplementation.class, 1);
        Test.stopTest();
        
        Integer expectedRunning = 1;
        Integer actualRunning = [SELECT COUNT() FROM AsyncApexJob];
        System.assertEquals(expectedRunning, actualRunning);
        
        String serializedOne = System.Json.serializePretty(one.getSObject().Id);
        String serializedTwo = System.Json.serializePretty(two.getSObject().Id);
        System.assertEquals(serializedOne, serializedTwo);
    }

}