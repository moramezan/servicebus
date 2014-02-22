@isTest private class ProcessRefreshBatchTest {
    
    static testMethod void testRecordCreatedForPluginAndStateful() {
        //arrange
        ProcessRefreshBatch batch = new ProcessRefreshBatch();
        batch.query = 'SELECT Id, NamespacePrefix, Name FROM ApexClass WHERE Name = \'Terminate\' ORDER BY Name ASC LIMIT 1';
        
        //act
        Test.startTest();
        Database.executeBatch(batch);
        Test.stopTest();
        List<Process__c> processes = [SELECT Id, Name, Description__c, Tag__c FROM Process__c];
        
        //assert
        Integer expectedCount = 1;
        Integer actualCount = processes.size();
        System.assertEquals(expectedCount, actualCount);
        
        String expectedName = 'Terminate';
        String actualName = processes[0].Name;
        System.assert(actualName.contains(expectedName));

        String expectedDescription = 'terminates each sequence';
        String actualDescription = processes[0].Description__c;
        System.assert(actualDescription.contains(expectedDescription));
        
        String expectedTag = 'Event Driven Architecture';
        String actualTag = processes[0].Tag__c;
        System.assert(actualDescription.contains(expectedDescription));
    }
    

 
    static testMethod void testImplementsEdaSubclass() {
        // arrange
        Type gate = Type.forName('Gate.Eda');
        Type mark = Type.forName('Mark.Eda');
        Type terminate = Type.forName('Terminate.Eda');
        Type branch = Type.forName('Branch.Eda');
        Type wiretap = Type.forName('Wiretap.Eda');
        Type publish = Type.forName('Publish.Eda');
        Type schedule = Type.forName('Schedule.Eda');
        Type subsequence = Type.forName('Subsequence.Eda');
        Type subscribe = Type.forName('Subscribe.Eda');
        Type scrape = Type.forName('Scrape.Eda');
        Type isChanged = Type.forName('IsChanged.Eda');
        Type debouncer = Type.forName('Debouncer.Eda');
        Type logInitializer = Type.forName('LogInitializer.Eda');
        Type logWriter = Type.forName('LogWriter.Eda');
        
        // act
        Boolean actualGate = (gate != null);
        Boolean actualMark = (mark != null);
        Boolean actualTerminate = (terminate != null);
        Boolean actualBranch = (branch != null);
        Boolean actualWiretap = (wiretap != null);
        Boolean actualPublish = (publish != null) ;
        Boolean actualSchedule = (schedule != null);
        Boolean actualSubsequence = (subsequence != null);
        Boolean actualSubscribe = (subscribe != null);
        Boolean actualScrape = (scrape != null);
        Boolean actualIsChanged = (isChanged != null);
        Boolean actualDebouncer = (debouncer != null);
        Boolean actualLogInitializer = (logInitializer != null);
        Boolean actualLogWriter = (logWriter != null);
        
        // assert
        System.assert(actualSubsequence);
        System.assert(actualBranch);
        System.assert(actualGate);
        System.assert(actualMark);
        System.assert(actualPublish);
        System.assert(actualSchedule);
        System.assert(actualTerminate);
        System.assert(actualSubscribe);
        System.assert(actualWiretap);
        System.assert(actualScrape);
        System.assert(actualIsChanged);
        System.assert(actualDebouncer);
        System.assert(actualLogInitializer);
        System.assert(actualLogWriter);
    }
   
}