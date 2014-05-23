@IsTest private class HeartbeatImplementationTest {
    
    static testmethod void testNoScheduledSequences() {
        Test.startTest();
        HeartbeatImplementation job = new HeartbeatImplementation();
        job.execute(null);
        Test.stopTest();
        
        Integer expectedCount = 0;
        Integer actualCount = [SELECT COUNT() FROM Message__c];
        System.assertEquals(expectedCount, actualCount);
    }
    
    /**
     * We need the DoNothing Broker because HeartbeatImplementation.execute
     * no longer inserts message, it actually causes the Broker to process
     * via enqueue. Gotta count the messages without them being processed!
     */
    public class DoNothingBroker extends Broker {
        override public void restartImpl() {}
        override public Boolean isAlreadyRunning() {return true;}
    }
    
    static testmethod void testOneScheduledSequence() {
        //arrange processes
        Process__c scheduleProcess = ProcessObject.generateOne(Schedule.class);
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        
        //arrange sequence
        Sequence__c one = new Sequence__c(Name = 'One');
        insert one;
        
        //arrange steps
        StepObjectSet.generateOne(one.Id, scheduleProcess.Id);
        StepObjectSet.generateOne(one.Id, terminateProcess.Id);
        
        List<ScheduleConfiguration__c> scheduleConfigurations = SalesforceObjectSet.listAll(ScheduleConfiguration__c.SObjectType);
        for (ScheduleConfiguration__c scheduleConfiguration : scheduleConfigurations) {
            scheduleConfiguration.Frequency__c = 'Weekly';
        }
        update scheduleConfigurations;
        
        insert new BrokerSettings__c(BrokerClassName__c = DoNothingBroker.class.getName());
        Test.startTest();
        HeartbeatImplementation job = new HeartbeatImplementation();
        SchedulableContext context = (SchedulableContext)Json.deserialize('{"Id": "08e000000000000"}', SchedulableContextImpl.class);
        Schedule.cronTrigger = (CronTrigger)Json.deserialize('{"PreviousFireTime": "2014-01-18T12:00:00.000Z"}', CronTrigger.class);
        job.execute(context);
        Test.stopTest();
        
        Integer expectedCount = 1;
        Integer actualCount = [SELECT COUNT() FROM Message__c];
        System.assertEquals(expectedCount, actualCount);
    }

}