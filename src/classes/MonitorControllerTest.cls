@IsTest public class MonitorControllerTest {
    
    static testmethod void testMessagesAggregatedOk() {
        //arrange processes, messages and controller
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        
        insert new Message__c(Status__c = 'Queued', Process__c = wiretapProcess.Id);
        insert new Message__c(Status__c = 'Buffered', Process__c = terminateProcess.Id);
        
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