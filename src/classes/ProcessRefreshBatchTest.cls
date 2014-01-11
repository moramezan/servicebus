@isTest public class ProcessRefreshBatchTest {
    
    static testMethod void testRecordCreatedForPluginAndStateful() {
        //arrange
        ProcessRefreshBatch batch = new ProcessRefreshBatch();
        batch.query += ' WHERE Name = \'Sink\'';
        
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
    

 
    static testMethod void testImplementsDatabaseStateful() {
        // arrange
        Process.Plugin boomerang = (Process.Plugin) new Boomerang();  
        Process.Plugin branch = (Process.Plugin) new Branch();
        Process.Plugin gate    = (Process.Plugin) new Gate();
        Process.Plugin mark    = (Process.Plugin) new Mark();
        Process.Plugin publish = (Process.Plugin) new Publish();
        Process.Plugin schedule    = (Process.Plugin) new Schedule();
        Process.Plugin sink = (Process.Plugin) new Sink();
        Process.Plugin subscribe = (Process.Plugin) new Subscribe();
        Process.Plugin wiretap = (Process.Plugin) new Wiretap();
        
        // act
        Boolean actualBoomerang = (boomerang instanceof Database.Stateful);  
        Boolean actualBranch = (branch instanceof Database.Stateful);
        Boolean actualGate = (gate instanceof Database.Stateful);
        Boolean actualMark = (mark instanceof Database.Stateful);
        Boolean actualPublish = (publish instanceof Database.Stateful) ;
        Boolean actualSchedule = (schedule instanceof Database.Stateful);
        Boolean actualSink = (sink instanceof Database.Stateful);
        Boolean actualSubscribe = (subscribe instanceof Database.Stateful);
        Boolean actualWiretap = (wiretap instanceof Database.Stateful); 
        
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