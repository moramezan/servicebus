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
        ApexClasses classes = ApexClasses.fromTypes(new List<Type>{Schedule.class, Terminate.class});
        List<Process__c> processes = classes.regenerate();
        insert processes;
        
        Chain__c one = new Chain__c(Name = 'One');
        insert one;
        insert new ChainStep__c(Chain__c = one.Id, Sequence__c = 1, Process__c = processes[0].Id);
        insert new ChainStep__c(Chain__c = one.Id, Sequence__c = 1, Process__c = processes[1].Id);
        
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