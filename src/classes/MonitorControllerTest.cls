@IsTest public class MonitorControllerTest {
    
    static testmethod void testMessagesAggregatedOk() {
        //arrange processes, messages and controller
        Process__c wiretapProcess = ProcessObject.generateOne(Wiretap.class);
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        
        insert new Message__c(Status__c = 'Queued', Process__c = wiretapProcess.Id);
        insert new Message__c(Status__c = 'Buffer', Process__c = terminateProcess.Id);
        
        MonitorController controller = new MonitorController();
        
        //act
        controller.doInit();
        
        //assert
        Integer expectedCount = 2;
        Integer actualCount = controller.Statistics.size();
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testmethod void coverDummyData() {
        MonitorController controller = new MonitorController();
        Integer count = controller.getTestStatistics().size();
        System.assert(count > 1);
    }

}