@IsTest private class ScheduleTest {

    static testmethod void hasTheCorrectLimits() {
        //assert
        Integer expectedLimits = 5000;
        Integer actualLimits = new Schedule.ESB().Limits;
        System.assertEquals(expectedLimits, actualLimits);
    }
    
    
    static testmethod void canDetermineStepConfig() {
        //arrange processes
        Process__c ScheduleProcess = ProcessModel.generateOne(Schedule.class);
        
        //act
        String actualConfig = ScheduleProcess.StepConfig__c;
        
        // Assert
        String expectedConfig = Schema.SobjectType.ScheduleConfig__c.Name;
        System.assertEquals(expectedConfig, actualConfig);
    }


    static testmethod void messagePassedThruUntouchedWhenIsHeartbeatEqFalse() {
        //arrange processes
        Process__c scheduleProcess = ProcessModel.generateOne(Schedule.class);
        Process__c terminateProcess = ProcessModel.generateOne(Terminate.class);
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'ScheduledSequence');
        insert sequence;
        
        //arrange steps
        Step__c scheduleStep = StepModel.generateOne(sequence.Id, scheduleProcess.Id);
        Step__c terminateStep = StepModel.generateOne(sequence.Id, terminateProcess.Id);


         //arrange input event
        Map<String,Object> inputEvent = new Map<String,Object>();
        inputEvent.put('esb__EntryPointDatetime', Json.serialize(System.now())); //#810
        inputEvent.put('__WasHeartbeatProcess', false);
        
        // act
        ProcessModel.BaseProcess process = new Schedule();
        List<Map<String,Object>> results = process.execute(inputEvent);
        
        // assemble
        Integer actualCount = results.size();

        Integer actualParameterSize = null;
        if (actualCount == 1) {
             Map<String,Object> actualParameters = results[0];
            actualParameterSize = actualParameters.keySet().size();
        }
        
        // assert
        Integer expectedCount = 1;
        System.assertEquals(expectedCount, actualCount);

        Integer expectedParameterSize = 2;
        System.assertEquals(expectedParameterSize, actualParameterSize);
    }


    static testmethod void messagePassedThruUntouchedWhenIsHeartbeatEqTrueAndIsWithinWindowReturnsTrue01() {
        //arrange processes
        Process__c scheduleProcess = ProcessModel.generateOne(Schedule.class);
        Process__c terminateProcess = ProcessModel.generateOne(Terminate.class);
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'ScheduledSequence');
        insert sequence;
        
        //arrange steps
        Step__c scheduleStep = StepModel.generateOne(sequence.Id, scheduleProcess.Id);
        Step__c terminateStep = StepModel.generateOne(sequence.Id, terminateProcess.Id);

        //arrange config
        ///Weekly    Sunday;Monday;Tuesday
        ScheduleConfig__c scheduleConfig = [SELECT Id FROM ScheduleConfig__c];
        scheduleConfig.IsActive__c = true;
        scheduleConfig.Frequency__c = 'Weekly';
        scheduleConfig.FriendlyDates__c = 'Wednesday';
        scheduleConfig.FriendlyTimes__c = '12:00';
        update scheduleConfig;
        

         //arrange input event parameters
        String stampAsString = '2014-01-15T12:00:00.000Z'; //15th Jan 2014 is a Wednesday
        Map<String,Object> inputEvent = new Map<String,Object>{
            'esb__StepConfig' => scheduleConfig,
            'esb__EntryPointDatetime' => stampAsString,
            '__WasHeartbeatProcess' => true
        };
 
        // act
        ProcessModel.BaseProcess process = new Schedule();
        List<Map<String,Object>> results = process.execute(inputEvent);
        
        // assemble
        Integer actualCount = results.size();

        String  actualStampTruncated = null;
        Integer actualParameterSize = null;
        if (actualCount == 1) {
             Map<String,Object> actualParameters = results[0];
            actualParameterSize = actualParameters.keySet().size();
            actualStampTruncated = (String)actualParameters.get('esb__EntryPointDatetime');
        }
        
        // assert
        Integer expectedCount = 1;
        System.assertEquals(expectedCount, actualCount);

        String  expectedStampTruncated = stampAsString;
        Integer expectedParameterSize = 3;
        System.assertEquals(expectedStampTruncated, actualStampTruncated);
        System.assertEquals(expectedParameterSize, actualParameterSize);
    }


    static testmethod void messagePassedThruUntouchedWhenIsHeartbeatEqTrueAndIsWithinWindowReturnsTrue02() {
        //arrange processes
        Process__c scheduleProcess = ProcessModel.generateOne(Schedule.class);
        Process__c terminateProcess = ProcessModel.generateOne(Terminate.class);
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'ScheduledSequence');
        insert sequence;
        
        //arrange steps
        Step__c scheduleStep = StepModel.generateOne(sequence.Id, scheduleProcess.Id);
        Step__c terminateStep = StepModel.generateOne(sequence.Id, terminateProcess.Id);

        //arrange config
        ///Daily    Working days only;Weekends and holidays
        ScheduleConfig__c scheduleConfig = [SELECT Id FROM ScheduleConfig__c];
        scheduleConfig.IsActive__c = true;
        scheduleConfig.Frequency__c = 'Daily';
        scheduleConfig.FriendlyDates__c = 'Working days only';
        scheduleConfig.FriendlyTimes__c = '12:00';
        update scheduleConfig;
        

         //arrange input event parameters
        String stampAsString = '2014-01-15T12:00:00.000Z'; //15th Jan 2014 is a Wednesday, a working day
        Map<String,Object> inputEvent = new Map<String,Object>{
            'esb__StepConfig' => scheduleConfig,
            'esb__EntryPointDatetime' => stampAsString,
            '__WasHeartbeatProcess' => true
        };
 
        // act
        ProcessModel.BaseProcess process = new Schedule();
        List<Map<String,Object>> results = process.execute(inputEvent);
        
        // assemble
        Integer actualCount = results.size();

        String  actualStampTruncated = null;
        Integer actualParameterSize = null;
        if (actualCount == 1) {
             Map<String,Object> actualParameters = results[0];
            actualParameterSize = actualParameters.keySet().size();
            actualStampTruncated = (String)actualParameters.get('esb__EntryPointDatetime');
        }
        
        // assert
        Integer expectedCount = 1;
        System.assertEquals(expectedCount, actualCount);

        String  expectedStampTruncated = stampAsString;
        Integer expectedParameterSize = 3;
        System.assertEquals(expectedStampTruncated, actualStampTruncated);
        System.assertEquals(expectedParameterSize, actualParameterSize);
    }


    static testmethod void messagePassedThruUntouchedWhenIsHeartbeatEqTrueAndIsWithinWindowReturnsTrue03() {
        //arrange processes
        Process__c scheduleProcess = ProcessModel.generateOne(Schedule.class);
        Process__c terminateProcess = ProcessModel.generateOne(Terminate.class);
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'ScheduledSequence');
        insert sequence;
        
        //arrange steps
        Step__c scheduleStep = StepModel.generateOne(sequence.Id, scheduleProcess.Id);
        Step__c terminateStep = StepModel.generateOne(sequence.Id, terminateProcess.Id);

        //arrange config
        ///Monthly    04;06
        ScheduleConfig__c scheduleConfig = [SELECT Id FROM ScheduleConfig__c];
        scheduleConfig.IsActive__c = true;
        scheduleConfig.Frequency__c = 'Monthly';
        scheduleConfig.FriendlyDates__c = '03;15;16';
        scheduleConfig.FriendlyTimes__c = '12:00';
        update scheduleConfig;
        

         //arrange input event parameters
        String stampAsString = '2014-01-03T12:00:00.000Z';
        Map<String,Object> inputEvent = new Map<String,Object>{
            'esb__StepConfig' => scheduleConfig,
            'esb__EntryPointDatetime' => stampAsString,
            '__WasHeartbeatProcess' => true
        };
 
        // act
        ProcessModel.BaseProcess process = new Schedule();
        List<Map<String,Object>> results = process.execute(inputEvent);
        
        // assemble
        Integer actualCount = results.size();

        String  actualStampTruncated = null;
        Integer actualParameterSize = null;
        if (actualCount == 1) {
             Map<String,Object> actualParameters = results[0];
            actualParameterSize = actualParameters.keySet().size();
            actualStampTruncated = (String)actualParameters.get('esb__EntryPointDatetime');
        }
        
        // assert
        Integer expectedCount = 1;
        System.assertEquals(expectedCount, actualCount);

        String  expectedStampTruncated = stampAsString;
        Integer expectedParameterSize = 3;
        System.assertEquals(expectedStampTruncated, actualStampTruncated);
        System.assertEquals(expectedParameterSize, actualParameterSize);
    }


    static testmethod void messageSwalloweddWhenIsHeartbeatEqTrueAndIsWithinWindowReturnsFalse() {
        //arrange processes
        Process__c scheduleProcess = ProcessModel.generateOne(Schedule.class);
        Process__c terminateProcess = ProcessModel.generateOne(Terminate.class);
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'ScheduledSequence');
        insert sequence;
        
        //arrange steps
        Step__c scheduleStep = StepModel.generateOne(sequence.Id, scheduleProcess.Id);
        Step__c terminateStep = StepModel.generateOne(sequence.Id, terminateProcess.Id);

        //arrange config
        ScheduleConfig__c scheduleConfig = [SELECT Id FROM ScheduleConfig__c];
        scheduleConfig.Frequency__c = 'Weekly';
        scheduleConfig.FriendlyDates__c = 'Wednesday';
        scheduleConfig.FriendlyTimes__c = '13:00';
        update scheduleConfig;
        

         //arrange input event parameters
        String stampAsString = '2014-01-18T12:00:00.000Z';
        Map<String,Object> inputEvent = new Map<String,Object>{
            'esb__StepConfig' => scheduleConfig,
            'esb__EntryPointDatetime' => stampAsString,
            '__WasHeartbeatProcess' => true
        };
 
        // act
        ProcessModel.BaseProcess process = new Schedule();
        List<Map<String,Object>> results = process.execute(inputEvent);
        
        // assemble
        Integer actualCount = results.size();

        // assert
        Integer expectedCount = 0;
        System.assertEquals(expectedCount, actualCount);
    }

    static testmethod void isHeartbeatThrowsExceptionWhenInvalidStampParam() {
        //arrange processes
        Process__c scheduleProcess = ProcessModel.generateOne(Schedule.class);
        Process__c terminateProcess = ProcessModel.generateOne(Terminate.class);
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'ScheduledSequence');
        insert sequence;
        
        //arrange steps
        Step__c scheduleStep = StepModel.generateOne(sequence.Id, scheduleProcess.Id);
        Step__c terminateStep = StepModel.generateOne(sequence.Id, terminateProcess.Id);
        

         //arrange input event parameters
        String invalidStamp = 'XXXX-01-18T12:00:00.000Z';
        Map<String,Object> inputEvent = new Map<String,Object>{
            'esb__StepConfig' => new ScheduleConfig__c(IsActive__c = true),
            'esb__EntryPointDatetime' => invalidStamp,
            '__WasHeartbeatProcess' => true
        };
        
        // assemble
        Boolean actualFlag = false;
        try {
            // act
            ProcessModel.BaseProcess process =  new Schedule();
            List<Map<String,Object>> result = process.execute(inputEvent);
        } catch (Schedule.ScheduleException e) {
            actualFlag = true;
        }
 
        // assert
        Boolean expectedFlag = true;
        System.assertEquals(expectedFlag, actualFlag);
    }


     static testmethod void callingIsTimeMatchReturnsTrueWhenTimeStampIsInRunTimes() {
        // arrange
        Set<String> runTimesA = new Set<String>{'12:00','11:00'};
        Set<String> runTimesB = new Set<String>{'12:00'};
        String stampAsString1 = '2014-01-18T12:00:00.000Z';
        String stampAsString2 = '2014-01-18 12:00:00.000';
        String stampAsString3 = '2014-01-18T12:00:00';
         
        // act
        Boolean actualFlag1 = Schedule.isTimeMatch(stampAsString1, runTimesA);
        Boolean actualFlag2 = Schedule.isTimeMatch(stampAsString1, runTimesA);
        Boolean actualFlag3 = Schedule.isTimeMatch(stampAsString1, runTimesA);
        Boolean actualFlag4 = Schedule.isTimeMatch(stampAsString1, runTimesB);
        Boolean actualFlag5 = Schedule.isTimeMatch(stampAsString1, runTimesB);
        Boolean actualFlag6 = Schedule.isTimeMatch(stampAsString1, runTimesB);

         
        // assert
        Boolean expectedFlag1 = true;
        System.assertEquals(expectedFlag1, actualFlag1);
        Boolean expectedFlag2 = true;
        System.assertEquals(expectedFlag2, actualFlag2);
        Boolean expectedFlag3 = true;
        System.assertEquals(expectedFlag3, actualFlag3);
        Boolean expectedFlag4 = true;
        System.assertEquals(expectedFlag4, actualFlag4);
        Boolean expectedFlag5 = true;
        System.assertEquals(expectedFlag5, actualFlag5);
        Boolean expectedFlag6 = true;
        System.assertEquals(expectedFlag6, actualFlag6);
     }


    static testmethod void testDailyWindow() {
        DateTime sundayNight = DateTime.newInstance(2014, 1, 19, 23, 59, 59); //19th Jan 2014 is a Sunday
        System.assert(!Schedule.isWithinDailyWindow(sundayNight, new Set<String>{'Working days only'}));
        System.assert(Schedule.isWithinDailyWindow(sundayNight, new Set<String>{'Weekends and holidays'}));

        DateTime wednesday = DateTime.newInstance(2014, 1, 15, 0, 0, 0); //15th Jan 2014 is a Wednesday
        System.assert(Schedule.isWithinDailyWindow(wednesday, new Set<String>{'Working days only','Weekends and holidays'}));
        System.assert(Schedule.isWithinDailyWindow(sundayNight, new Set<String>{'Working days only','Weekends and holidays'}));
    }


    static testmethod void testWeeklyWindow() {
        DateTime wednesday = DateTime.newInstance(2014, 1, 15, 9, 0, 0); //15th Jan 2014 is a Wednesday
        System.assert(Schedule.isWithinWeeklyWindow(wednesday, new Set<String>{'Tuesday', 'Wednesday', 'Thursday'}));
        
        DateTime friday = DateTime.newInstance(2014, 1, 17, 9, 0, 0); //17th Jan 2014 is a Friday
        System.assert(!Schedule.isWithinWeeklyWindow(wednesday, new Set<String>{'Thursday', 'Saturday'}));
        
        DateTime saturdayMorning = DateTime.newInstance(2014, 1, 18, 0, 0, 1); //18th Jan 2014 is a Satuday
        System.assert(!Schedule.isWithinWeeklyWindow(saturdayMorning, new Set<String>{'Friday'}));
        System.assert(Schedule.isWithinWeeklyWindow(saturdayMorning, new Set<String>{'Saturday'}));
        System.assert(!Schedule.isWithinWeeklyWindow(saturdayMorning, new Set<String>{'Sunday'}));
        
        DateTime saturdayNight = DateTime.newInstance(2014, 1, 18, 23, 59, 59); //18th Jan 2014 is a Saturday
        System.assert(!Schedule.isWithinWeeklyWindow(saturdayNight, new Set<String>{'Friday'}));
        System.assert(Schedule.isWithinWeeklyWindow(saturdayNight, new Set<String>{'Saturday'}));
        System.assert(!Schedule.isWithinWeeklyWindow(saturdayNight, new Set<String>{'Sunday'}));
    }


    static testmethod void testMonthlyWindow() {
        // arrange
        String christmasMorning = '2014-12-25T12:09:00.000Z';
        String newYearsDay = '2014-01-01T12:09:00.000Z';
        String independenceDay = '2014-07-04T12:09:00';

        // act
        System.assert(Schedule.isWithinMonthlyWindow(christmasMorning, new Set<String>{'24', '25', '26'}));
        System.assert(!Schedule.isWithinMonthlyWindow(newYearsDay, new Set<String>{'06', '02', '03'}));
        System.assert(Schedule.isWithinMonthlyWindow(independenceDay, new Set<String>{'04'}));
    }
     
}