@IsTest private class ScheduleTest {

    static testmethod void hasTheCorrectLimits() {
        //arrange
        ApexClassModel.ESB esb = ApexClassModel.esbFromEsb(Schedule.class);
        
        //assert
        Integer expectedLimits = 100;
        Integer actualLimits = esb.Limits;
        System.assertEquals(expectedLimits, actualLimits);
    }

   static testmethod void withinSystemLimits() {
        //arrange
        ApexClassModel.ESB esb = ApexClassModel.esbFromEsb(Schedule.class);
        
        //arrange
        Map<String,Object> inputEvent = new Map<String,Object> {};
        
        //act
        Test.startTest();
        Integer limits = esb.Limits;
        Integer counter = 0;
        for (Integer i = 0; i < limits; i++) {
            ApexClassModel.BaseProcess process = new Schedule();
            List<Map<String,Object>> outputs = process.test(inputEvent);
            counter++;
        }
        Test.stopTest();

        //assert
        System.assertEquals(limits, counter, 'Limit not reached.');
   }

    
    static testmethod void messagePassedThruUntouchedWhenIsHeartbeatEqFalse() {
        //arrange input event
        Map<String,Object> inputEvent = new Map<String,Object>();
        inputEvent.put('esb__EntryPointDatetime', System.now()); //#810
        inputEvent.put('__WasHeartbeatProcess', false);
        
        //act
        ApexClassModel.BaseProcess process = new Schedule();
        List<Map<String,Object>> outputEvents = process.test(inputEvent);
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
    }
    
    static testmethod void messagePassedThruUntouchedWhenIsHeartbeatEqTrueAndIsWithinWindowReturnsTrue01() {
        //arrange config
        insert new ScheduleConfig__c(
            IsActive__c = true,
            Frequency__c = 'Weekly',
            FriendlyDates__c = 'Wednesday',
            FriendlyTimes__c = '12:00'
        );

        //arrange input
        Datetime entryPoint = Datetime.newInstanceGmt(2014, 1, 15, 12, 0, 0); //15th Jan 2014 is a Wednesday
        Map<String,Object> inputEvent = new Map<String,Object>{
            'esb__StepConfigId' => [SELECT Id FROM ScheduleConfig__c].Id,
            'esb__EntryPointDatetime' => entryPoint,
            '__WasHeartbeatProcess' => true
        };
        
        //act
        ApexClassModel.BaseProcess process = new Schedule();
        List<Map<String,Object>> outputEvents = process.test(inputEvent);
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
        
        String expectedEntryPoint = '2014-01-15T12:00:00.000Z';
        String actualEntryPoint = (String)outputEvents[0].get('esb__EntryPointDatetime');
        System.assertEquals(expectedEntryPoint, actualEntryPoint, 'Wrong entry point datetime.');
    }

    static testmethod void messagePassedThruUntouchedWhenIsHeartbeatEqTrueAndIsWithinWindowReturnsTrue02() {
        //arrange config
        insert new ScheduleConfig__c(
            IsActive__c = true,
            Frequency__c = 'Daily',
            FriendlyDates__c = 'Working days only',
            FriendlyTimes__c = '12:00'
        );
        
        //arrange input
        Datetime entryPoint = Datetime.newInstanceGmt(2014, 1, 15, 12, 0, 0); //15th Jan 2014 is a Wednesday, a working day
        Map<String,Object> inputEvent = new Map<String,Object>{
            'esb__StepConfigId' => [SELECT Id FROM ScheduleConfig__c].Id,
            'esb__EntryPointDatetime' => entryPoint,
            '__WasHeartbeatProcess' => true
        };
        
        ///act on working days only
        ApexClassModel.BaseProcess process = new Schedule();
        List<Map<String,Object>> outputEvents = process.test(inputEvent);
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
        
        String expectedEntryPoint = '2014-01-15T12:00:00.000Z';
        String actualEntryPoint = (String)outputEvents[0].get('esb__EntryPointDatetime');
        System.assertEquals(expectedEntryPoint, actualEntryPoint, 'Wrong entry point datetime.');
    }
    
    static testmethod void messagePassedThruUntouchedWhenIsHeartbeatEqTrueAndIsWithinWindowReturnsTrue03() {
        //arrange config
        insert new ScheduleConfig__c(
            IsActive__c = true,
            Frequency__c = 'Monthly',
            FriendlyDates__c = '03;15;16',
            FriendlyTimes__c = '12:00'
        );
        
        //arrange input
        Datetime entryPoint = Datetime.newInstanceGmt(2014, 1, 3, 12, 0, 0);
        Map<String,Object> inputEvent = new Map<String,Object>{
            'esb__StepConfigId' => [SELECT Id FROM ScheduleConfig__c].Id,
            'esb__EntryPointDatetime' => entryPoint,
            '__WasHeartbeatProcess' => true
        };
 
        //act
        ApexClassModel.BaseProcess process = new Schedule();
        List<Map<String,Object>> outputEvents = process.test(inputEvent);
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
        
        String expectedEntryPoint = '2014-01-03T12:00:00.000Z';
        String actualEntryPoint = (String)outputEvents[0].get('esb__EntryPointDatetime');
        System.assertEquals(expectedEntryPoint, actualEntryPoint, 'Wrong entry point datetime.');
    }
    
    static testmethod void messageSwallowedWhenIsHeartbeatEqTrueAndIsWithinWindowReturnsFalse() {
        //arrange config
        insert new ScheduleConfig__c(
            Frequency__c = 'Weekly',
            FriendlyDates__c = 'Wednesday',
            FriendlyTimes__c = '13:00'
        );
        
        //arrange input event parameters
        Datetime entryPoint = Datetime.newInstanceGmt(2014, 1, 18, 12, 0, 0);
        Map<String,Object> inputEvent = new Map<String,Object>{
            'esb__StepConfigId' => [SELECT Id FROM ScheduleConfig__c].Id,
            'esb__EntryPointDatetime' => entryPoint,
            '__WasHeartbeatProcess' => true
        };
 
        //act
        ApexClassModel.BaseProcess process = new Schedule();
        List<Map<String,Object>> outputEvents = process.test(inputEvent);
        
        //assert
        Integer expectedSize = 0;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
    }
    
    static testmethod void isHeartbeatThrowsExceptionWhenInvalidStampParam() {
        //arrange config
        insert new ScheduleConfig__c(
            IsActive__c = true
        );
        
        //arrange input
        Datetime entryPoint = null;
        Map<String,Object> inputEvent = new Map<String,Object>{
            'esb__StepConfigId' => [SELECT Id FROM ScheduleConfig__c].Id,
            'esb__EntryPointDatetime' => entryPoint,
            '__WasHeartbeatProcess' => true
        };
        
        try {
            //act
            ApexClassModel.BaseProcess process =  new Schedule();
            process.test(inputEvent);
            System.assert(false, 'Line above should throw exception.');
        } catch (Exception e) {
            //assert
            String expectedMessage = 'Problem with getISO8601 or getStamp("null")';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage, 'Wrong message.');
        }
    }
    
    static testmethod void callingIsTimeMatchReturnsTrueWhenTimeStampIsInRunTimes() {
        //arrange
        Set<String> runTimesA = new Set<String>{'12:00','11:00'};
        Set<String> runTimesB = new Set<String>{'12:00'};
        String stampAsString1 = '2014-01-18T12:00:00.000Z';
        String stampAsString2 = '2014-01-18 12:00:00.000';
        String stampAsString3 = '2014-01-18T12:00:00';
        
        //act and assert
        System.assert(Schedule.isTimeMatch(stampAsString1, runTimesA));
        System.assert(Schedule.isTimeMatch(stampAsString1, runTimesA));
        System.assert(Schedule.isTimeMatch(stampAsString1, runTimesA));
        System.assert(Schedule.isTimeMatch(stampAsString1, runTimesB));
        System.assert(Schedule.isTimeMatch(stampAsString1, runTimesB));
        System.assert(Schedule.isTimeMatch(stampAsString1, runTimesB));
    }
    
    static testmethod void testDailyWindow() {
        //arrange
        DateTime sundayNight = DateTime.newInstance(2014, 1, 19, 23, 59, 59); //19th Jan 2014 is a Sunday
        DateTime wednesday = DateTime.newInstance(2014, 1, 15, 0, 0, 0); //15th Jan 2014 is a Wednesday
        
        //act and assert
        System.assert(!Schedule.isWithinDailyWindow(sundayNight, new Set<String>{'Working days only'}));
        System.assert(Schedule.isWithinDailyWindow(sundayNight, new Set<String>{'Weekends and holidays'}));
        System.assert(Schedule.isWithinDailyWindow(sundayNight, new Set<String>{'Working days only','Weekends and holidays'}));
        System.assert(Schedule.isWithinDailyWindow(wednesday, new Set<String>{'Working days only','Weekends and holidays'}));
    }
    
    static testmethod void testWeeklyWindow() {
        //arrange
        DateTime wednesday = DateTime.newInstance(2014, 1, 15, 9, 0, 0); //15th Jan 2014 is a Wednesday
        DateTime saturdayMorning = DateTime.newInstance(2014, 1, 18, 0, 0, 1); //18th Jan 2014 is a Satuday
        DateTime saturdayNight = DateTime.newInstance(2014, 1, 18, 23, 59, 59); //18th Jan 2014 is a Saturday
        
        //act and assert
        System.assert(Schedule.isWithinWeeklyWindow(wednesday, new Set<String>{'Tuesday', 'Wednesday', 'Thursday'}));
        System.assert(!Schedule.isWithinWeeklyWindow(wednesday, new Set<String>{'Thursday', 'Saturday'}));
        System.assert(!Schedule.isWithinWeeklyWindow(saturdayMorning, new Set<String>{'Friday'}));
        System.assert(Schedule.isWithinWeeklyWindow(saturdayMorning, new Set<String>{'Saturday'}));
        System.assert(!Schedule.isWithinWeeklyWindow(saturdayMorning, new Set<String>{'Sunday'}));
        System.assert(!Schedule.isWithinWeeklyWindow(saturdayNight, new Set<String>{'Friday'}));
        System.assert(Schedule.isWithinWeeklyWindow(saturdayNight, new Set<String>{'Saturday'}));
        System.assert(!Schedule.isWithinWeeklyWindow(saturdayNight, new Set<String>{'Sunday'}));
    }
    
    static testmethod void testMonthlyWindow() {
        //arrange
        String christmasMorning = '2014-12-25T12:09:00.000Z';
        String newYearsDay = '2014-01-01T12:09:00.000Z';
        String independenceDay = '2014-07-04T12:09:00';

        //act and assert
        System.assert(Schedule.isWithinMonthlyWindow(christmasMorning, new Set<String>{'24', '25', '26'}));
        System.assert(!Schedule.isWithinMonthlyWindow(newYearsDay, new Set<String>{'06', '02', '03'}));
        System.assert(Schedule.isWithinMonthlyWindow(independenceDay, new Set<String>{'04'}));
    }
     
}