@isTest private class ScheduleImplementationTest {
    
    static testMethod void testNoScheduledChains() {
        Test.startTest();
        ScheduleImplementation job = new ScheduleImplementation();
        job.execute(null);
        Test.stopTest();
        
        Integer expectedCount = 0;
        Integer actualCount = [SELECT COUNT() FROM PersistentData__c];
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testMethod void testOneScheduledChain() {
        //arrange processes
        Process__c scheduleProcess = Processes.generateOne(Schedule.class);
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        
        //arrange chain
        Chain__c one = new Chain__c(Name = 'One');
        insert one;
        
        //arrange steps
        ChainSteps.generateOne(one.Id, scheduleProcess.Id);
        ChainSteps.generateOne(one.Id, terminateProcess.Id);
        
        List<ScheduleConfiguration__c> scheduleConfigurations = [SELECT Id FROM ScheduleConfiguration__c];
        for (ScheduleConfiguration__c scheduleConfiguration : scheduleConfigurations) {
            scheduleConfiguration.Frequency__c = 'Weekly';
        }
        update scheduleConfigurations;
        
        Test.startTest();
        ScheduleImplementation job = new ScheduleImplementation();
        job.execute(null);
        Test.stopTest();
        
        Integer expectedCount = 1;
        Integer actualCount = [SELECT COUNT() FROM PersistentData__c];
        System.assertEquals(expectedCount, actualCount);
    }

}