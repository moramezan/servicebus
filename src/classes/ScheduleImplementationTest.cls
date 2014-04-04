@isTest private class ScheduleImplementationTest {
    
    static testMethod void testNoScheduledSequences() {
        Test.startTest();
        ScheduleImplementation job = new ScheduleImplementation();
        job.execute(null);
        Test.stopTest();
        
        Integer expectedCount = 0;
        Integer actualCount = [SELECT COUNT() FROM Message__c];
        System.assertEquals(expectedCount, actualCount);
    }
    
    static testMethod void testOneScheduledSequence() {
        //arrange processes
        Process__c scheduleProcess = ProcessSet.generateOne(Schedule.class);
        Process__c terminateProcess = ProcessSet.generateOne(Terminate.class);
        
        //arrange sequence
        Sequence__c one = new Sequence__c(Name = 'One');
        insert one;
        
        //arrange steps
        StepSet.generateOne(one.Id, scheduleProcess.Id);
        StepSet.generateOne(one.Id, terminateProcess.Id);
        
        List<ScheduleConfiguration__c> scheduleConfigurations = SalesforceObjectSet.listAll(ScheduleConfiguration__c.SObjectType);
        for (ScheduleConfiguration__c scheduleConfiguration : scheduleConfigurations) {
            scheduleConfiguration.Frequency__c = 'Weekly';
        }
        update scheduleConfigurations;
        
        Test.startTest();
        ScheduleImplementation job = new ScheduleImplementation();
        job.execute(null);
        Test.stopTest();
        
        Integer expectedCount = 1;
        Integer actualCount = [SELECT COUNT() FROM Message__c];
        System.assertEquals(expectedCount, actualCount);
    }

}