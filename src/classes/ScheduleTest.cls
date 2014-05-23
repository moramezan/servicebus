@IsTest private class ScheduleTest {
    static testmethod void testPassThrueScenarioHandled() {
        //arrange processes
        Process__c scheduleProcess = ProcessObject.generateOne(Schedule.class);
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'ScheduledSequence');
        insert sequence;
        
        //arrange steps
        Step__c scheduleStep = StepObjectSet.generateOne(sequence.Id, scheduleProcess.Id);
        
        ScheduleConfiguration__c scheduleConfiguration = [SELECT Id FROM ScheduleConfiguration__c];
        scheduleConfiguration.Frequency__c = 'Weekly';
        scheduleConfiguration.FriendlyDates__c = 'Wednesday';
        scheduleConfiguration.FriendlyTimes__c = '09:00';
        update scheduleConfiguration;
        
        Step__c terminateStep = StepObjectSet.generateOne(sequence.Id, terminateProcess.Id);
        
        //this guy will miss his schedule
        Map<String,Object> parameters = new Map<String,Object>{
           //-- NO eda_Heartbeat ::  'eda_Heartbeat' => '2014-01-18T12:00:00.000Z', /
            'eda_ConfigObjectId' => [SELECT Id FROM ScheduleConfiguration__c].Id
        };
        
        Schedule plugin = new Schedule();
        Process.PluginResult result = plugin.invoke(new Process.PluginRequest(parameters));
        List<Map<String,Object>> results = EdaUtility.convert(result);
        
 
        
        //this guy will hit his schedule
       ///-- NO eda_Heartbeat ::  parameters.put('eda_Heartbeat', '2014-01-15T09:00:00.000Z');
        result = plugin.invoke(new Process.PluginRequest(parameters));
        results = EdaUtility.convert(result);
        
        Integer expectedHitCount = 1;
        Integer actualHitCount = results.size();
        System.assertEquals(expectedHitCount, actualHitCount);
    }
    static testmethod void testHeartbeatHandled() {
        //arrange processes
        Process__c scheduleProcess = ProcessObject.generateOne(Schedule.class);
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'ScheduledSequence');
        insert sequence;
        
        //arrange steps
        Step__c scheduleStep = StepObjectSet.generateOne(sequence.Id, scheduleProcess.Id);
        
        ScheduleConfiguration__c scheduleConfiguration = [SELECT Id FROM ScheduleConfiguration__c];
        scheduleConfiguration.Frequency__c = 'Weekly';
        scheduleConfiguration.FriendlyDates__c = 'Wednesday';
        scheduleConfiguration.FriendlyTimes__c = '09:00';
        update scheduleConfiguration;
        
        Step__c terminateStep = StepObjectSet.generateOne(sequence.Id, terminateProcess.Id);
        
        //this guy will miss his schedule (it is not Wednesday at 9:00)
        Schedule.cronTrigger = (CronTrigger)Json.deserialize('{"PreviousFireTime": "2014-01-18T12:00:00.000Z"}', CronTrigger.class);
        Map<String,Object> parameters = new Map<String,Object>{
            'Id' => '08e000000000000',
            'eda_ConfigObjectId' => [SELECT Id FROM ScheduleConfiguration__c].Id
        };
        
        Schedule plugin = new Schedule();
        Process.PluginResult result = plugin.invoke(new Process.PluginRequest(parameters));
        List<Map<String,Object>> results = EdaUtility.convert(result);
        
        Integer expectedMissCount = 0;
        Integer actualMissCount = results.size();
        System.assertEquals(expectedMissCount, actualMissCount);
        
        //this guy will hit his schedule
        Schedule.cronTrigger = (CronTrigger)Json.deserialize('{"PreviousFireTime": "2014-01-15T09:00:00.000Z"}', CronTrigger.class); //definitely a Wednesday at 9:00
        result = plugin.invoke(new Process.PluginRequest(parameters));
        results = EdaUtility.convert(result);
        
        Integer expectedHitCount = 1;
        Integer actualHitCount = results.size();
        System.assertEquals(expectedHitCount, actualHitCount);
    }
    
    static testmethod void testMonthlyWindow() {
        DateTime christmasMorning = DateTime.newInstanceGmt(2014, 12, 25, 9, 0, 0);
        System.assert(Schedule.isWithinMonthlyWindow(christmasMorning, new Set<String>{'24', '25', '26'}));
        
        DateTime newYearsDay = DateTime.newInstanceGmt(2014, 1, 1, 9, 0, 0);
        System.assert(!Schedule.isWithinMonthlyWindow(newYearsDay, new Set<String>{'2', '3', '4'}));
        
        DateTime independenceDay = DateTime.newInstanceGmt(2014, 7, 4, 9, 0, 0);
        System.assert(Schedule.isWithinMonthlyWindow(independenceDay, new Set<String>{'4'}));
    }
    
    static testmethod void testWeeklyWindow() {
        DateTime wednesday = DateTime.newInstanceGmt(2014, 1, 15, 9, 0, 0); //15th Jan 2014 is a Wednesday
        System.assert(Schedule.isWithinWeeklyWindow(wednesday, new Set<String>{'Tuesday', 'Wednesday', 'Thursday'}));
        
        DateTime friday = DateTime.newInstanceGmt(2014, 1, 17, 9, 0, 0); //17th Jan 2014 is a Friday
        System.assert(!Schedule.isWithinWeeklyWindow(wednesday, new Set<String>{'Thursday', 'Saturday'}));
        
        DateTime saturdayMorning = DateTime.newInstanceGmt(2014, 1, 18, 0, 0, 1); //18th Jan 2014 is a Satuday
        System.assert(!Schedule.isWithinWeeklyWindow(saturdayMorning, new Set<String>{'Friday'}));
        System.assert(Schedule.isWithinWeeklyWindow(saturdayMorning, new Set<String>{'Saturday'}));
        System.assert(!Schedule.isWithinWeeklyWindow(saturdayMorning, new Set<String>{'Sunday'}));
        
        DateTime saturdayNight = DateTime.newInstanceGmt(2014, 1, 18, 23, 59, 59); //18th Jan 2014 is a Saturday
        System.assert(!Schedule.isWithinWeeklyWindow(saturdayNight, new Set<String>{'Friday'}));
        System.assert(Schedule.isWithinWeeklyWindow(saturdayNight, new Set<String>{'Saturday'}));
        System.assert(!Schedule.isWithinWeeklyWindow(saturdayNight, new Set<String>{'Sunday'}));
    }
    
    static testmethod void testDailyWindow() {
        DateTime sundayNight = DateTime.newInstanceGmt(2014, 1, 19, 23, 59, 59); //19th Jan 2014 is a Sunday
        System.assert(!Schedule.isWithinDailyWindow(sundayNight, new Set<String>{'Working days only'}));
        System.assert(Schedule.isWithinDailyWindow(sundayNight, new Set<String>{'Weekends and holidays'}));

        DateTime wednesday = DateTime.newInstanceGmt(2014, 1, 15, 0, 0, 0); //15th Jan 2014 is a Wednesday
        System.assert(Schedule.isWithinDailyWindow(wednesday, new Set<String>{'Working days only','Weekends and holidays'}));
        System.assert(Schedule.isWithinDailyWindow(sundayNight, new Set<String>{'Working days only','Weekends and holidays'}));
    }
    
    static testmethod void testHourlyWindow() {
        DateTime preNoon = DateTime.newInstanceGmt(2014, 12, 25, 11, 0, 0);
        DateTime noon = DateTime.newInstanceGmt(2014, 12, 25, 12, 0, 0);
        DateTime postNoon = DateTime.newInstanceGmt(2014, 12, 25, 13, 0, 0);
        
        System.assert(!Schedule.isWithinHourlyWindow(preNoon, new Set<String>{'10:00','12:00'}));
        System.assert(Schedule.isWithinHourlyWindow(noon, new Set<String>{'12:00'}));
        System.assert(!Schedule.isWithinHourlyWindow(postNoon, new Set<String>{'12:00','14:00'}));
    }
    
    static testmethod void testWindow() {
        DateTime christmasMorning = DateTime.newInstanceGmt(2013, 12, 25, 9, 0, 0); //christmas was a wednesday
        ScheduleConfiguration__c config = new ScheduleConfiguration__c(Frequency__c = 'Weekly', FriendlyDates__c = 'Wednesday');
        
        config.FriendlyTimes__c = '08:00';
        System.assert(!Schedule.isWithinWindow(christmasMorning, config));
        
        config.FriendlyTimes__c = '09:00';
        System.assert(Schedule.isWithinWindow(christmasMorning, config));
        
        config.FriendlyTimes__c = '10:00';
        System.assert(!Schedule.isWithinWindow(christmasMorning, config));
    }
    
    
}