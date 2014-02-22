@isTest private class ScheduleTest {
    static testMethod void testPassThrueScenarioHandled() {
        //arrange processes
        Process__c scheduleProcess = Processes.generateOne(Schedule.class);
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        
        //arrange chain
        Chain__c chain = new Chain__c(Name = 'ScheduledChain');
        insert chain;
        
        //arrange steps
        Step__c scheduleStep = Steps.generateOne(chain.Id, scheduleProcess.Id);
        
        ScheduleConfiguration__c scheduleConfiguration = [SELECT Id FROM ScheduleConfiguration__c];
        scheduleConfiguration.Frequency__c = 'Weekly';
        scheduleConfiguration.FriendlyDates__c = 'Wednesday';
        scheduleConfiguration.FriendlyTimes__c = '09:00';
        update scheduleConfiguration;
        
        Step__c terminateStep = Steps.generateOne(chain.Id, terminateProcess.Id);
        
        //this guy will miss his schedule
        Map<String,Object> parameters = new Map<String,Object>{
           //-- NO eda__harbeatkey ::  'eda__heartbeat' => '2014-01-18T12:00:00.000Z', /
            'eda__configuration' => [SELECT Id FROM ScheduleConfiguration__c].Id
        };
        
        Schedule plugin = new Schedule();
        Process.PluginResult result = plugin.invoke(new Process.PluginRequest(parameters));
        List<Map<String,Object>> results = Utility.convert(result);
        
 
        
        //this guy will hit his schedule
       ///-- NO eda__harbeatkey ::  parameters.put('eda__heartbeat', '2014-01-15T09:00:00.000Z');
        result = plugin.invoke(new Process.PluginRequest(parameters));
        results = Utility.convert(result);
        
        Integer expectedHitCount = 1;
        Integer actualHitCount = results.size();
        System.assertEquals(expectedHitCount, actualHitCount);
    }
    static testMethod void testHeartbeatHandled() {
        //arrange processes
        Process__c scheduleProcess = Processes.generateOne(Schedule.class);
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        
        //arrange chain
        Chain__c chain = new Chain__c(Name = 'ScheduledChain');
        insert chain;
        
        //arrange steps
        Step__c scheduleStep = Steps.generateOne(chain.Id, scheduleProcess.Id);
        
        ScheduleConfiguration__c scheduleConfiguration = [SELECT Id FROM ScheduleConfiguration__c];
        scheduleConfiguration.Frequency__c = 'Weekly';
        scheduleConfiguration.FriendlyDates__c = 'Wednesday';
        scheduleConfiguration.FriendlyTimes__c = '09:00';
        update scheduleConfiguration;
        
        Step__c terminateStep = Steps.generateOne(chain.Id, terminateProcess.Id);
        
        //this guy will miss his schedule
        Map<String,Object> parameters = new Map<String,Object>{
            'eda__heartbeat' => '2014-01-18T12:00:00.000Z', //not Wednesday at 9:00
            'eda__configuration' => [SELECT Id FROM ScheduleConfiguration__c].Id
        };
        
        Schedule plugin = new Schedule();
        Process.PluginResult result = plugin.invoke(new Process.PluginRequest(parameters));
        List<Map<String,Object>> results = Utility.convert(result);
        
        Integer expectedMissCount = 0;
        Integer actualMissCount = results.size();
        System.assertEquals(expectedMissCount, actualMissCount);
        
        //this guy will hit his schedule
        parameters.put('eda__heartbeat', '2014-01-15T09:00:00.000Z'); //definitely a Wednesday at 9:00
        result = plugin.invoke(new Process.PluginRequest(parameters));
        results = Utility.convert(result);
        
        Integer expectedHitCount = 1;
        Integer actualHitCount = results.size();
        System.assertEquals(expectedHitCount, actualHitCount);
    }
    
    static testMethod void testMonthlyWindow() {
        DateTime christmasMorning = DateTime.newInstanceGmt(2014, 12, 25, 9, 0, 0);
        System.assert(Schedule.isWithinMonthlyWindow(christmasMorning, new Set<String>{'24', '25', '26'}));
        
        DateTime newYearsDay = DateTime.newInstanceGmt(2014, 1, 1, 9, 0, 0);
        System.assert(!Schedule.isWithinMonthlyWindow(newYearsDay, new Set<String>{'2', '3', '4'}));
        
        DateTime independenceDay = DateTime.newInstanceGmt(2014, 7, 4, 9, 0, 0);
        System.assert(Schedule.isWithinMonthlyWindow(independenceDay, new Set<String>{'4'}));
    }
    
    static testMethod void testWeeklyWindow() {
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
    
    static testMethod void testDailyWindow() {
        DateTime sundayNight = DateTime.newInstanceGmt(2014, 1, 19, 23, 59, 59); //19th Jan 2014 is a Sunday
        System.assert(!Schedule.isWithinDailyWindow(sundayNight, new Set<String>{'Working days only'}));
        System.assert(Schedule.isWithinDailyWindow(sundayNight, new Set<String>{'Weekends and holidays'}));

        DateTime wednesday = DateTime.newInstanceGmt(2014, 1, 15, 0, 0, 0); //15th Jan 2014 is a Wednesday
        System.assert(Schedule.isWithinDailyWindow(wednesday, new Set<String>{'Working days only','Weekends and holidays'}));
        System.assert(Schedule.isWithinDailyWindow(sundayNight, new Set<String>{'Working days only','Weekends and holidays'}));
    }
    
    static testMethod void testHourlyWindow() {
        DateTime preNoon = DateTime.newInstanceGmt(2014, 12, 25, 11, 0, 0);
        DateTime noon = DateTime.newInstanceGmt(2014, 12, 25, 12, 0, 0);
        DateTime postNoon = DateTime.newInstanceGmt(2014, 12, 25, 13, 0, 0);
        
        System.assert(!Schedule.isWithinHourlyWindow(preNoon, new Set<String>{'10:00','12:00'}));
        System.assert(Schedule.isWithinHourlyWindow(noon, new Set<String>{'12:00'}));
        System.assert(!Schedule.isWithinHourlyWindow(postNoon, new Set<String>{'12:00','14:00'}));
    }
    
    static testMethod void testWindow() {
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