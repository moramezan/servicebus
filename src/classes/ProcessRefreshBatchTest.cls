@isTest private class ProcessRefreshBatchTest {
    
    static testMethod void testRecordCreatedForPluginAndStateful() {
        //arrange
        ProcessRefreshBatch batch = new ProcessRefreshBatch();
        batch.query = 'SELECT Id, NamespacePrefix, Name FROM ApexClass WHERE Name = \'Sink\' ORDER BY Name ASC LIMIT 1';
        
        //act
        Test.startTest();
        Database.executeBatch(batch);
        Test.stopTest();
        List<Process__c> processes = [SELECT Id, Name, Description__c, Tag__c FROM Process__c];
        
        //assert
        Integer expectedCount = 1;
        Integer actualCount = processes.size();
        System.assertEquals(expectedCount, actualCount);
        
        String expectedName = 'Sink';
        String actualName = processes[0].Name;
        System.assert(actualName.contains(expectedName));

        String expectedDescription = 'terminates all chains';
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
        Type sink = Type.forName('Sink.Eda');
        Type branch = Type.forName('Branch.Eda');
        Type wiretap = Type.forName('Wiretap.Eda');
        Type publish = Type.forName('Publish.Eda');
        Type schedule = Type.forName('Schedule.Eda');
        Type boomerang = Type.forName('Boomerang.Eda');  
        Type subscribe = Type.forName('Subscribe.Eda');
        
        // act
        Boolean actualGate = (gate != null);
        Boolean actualMark = (mark != null);
        Boolean actualSink = (sink != null);
        Boolean actualBranch = (branch != null);
        Boolean actualWiretap = (wiretap != null); 
        Boolean actualPublish = (publish != null) ;
        Boolean actualSchedule = (schedule != null);
        Boolean actualBoomerang = (boomerang != null);  
        Boolean actualSubscribe = (subscribe != null);
        
        // assert
        System.assert(actualBoomerang); 
        System.assert(actualBranch);
        System.assert(actualGate);
        System.assert(actualMark);
        System.assert(actualPublish);
        System.assert(actualSchedule);
        System.assert(actualSink);
        System.assert(actualSubscribe);
        System.assert(actualWiretap);
    }
   
}