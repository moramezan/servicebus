@IsTest public class MonitorControllerTest {
    
    static testmethod void testMessagesAggregatedOk() {
        //arrange processes, messages and controller
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        
        MessageObjectSet.Inhibit = false;
        insert new Message__c(Status__c = 'Queued');
        insert new Message__c(Status__c = 'Buffered');
        MessageObjectSet.Inhibit = true;
        
        //act
        List<MonitorController.Statistic> statistics = MonitorController.getStatistics();
        
        //assert
        Integer expectedCount = 2;
        Integer actualCount = statistics.size();
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testmethod void coverDummyData() {
        Integer count = MonitorController.getTestStatistics().size();
        System.assert(count > 1);
    }

}