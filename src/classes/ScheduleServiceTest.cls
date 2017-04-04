@IsTest class ScheduleServiceTest {

    static testmethod void hasTheCorrectChunks() {
        //arrange
        ApexClassModel.Definition definition = new ApexClassModel.Definition(ScheduleService.class);
        
        //assert
        Integer expectedChunks = 100;
        Integer actualChunks = definition.Chunks;
        System.assertEquals(expectedChunks, actualChunks);
    }
    
    static testmethod void withinSystemLimits() {
        //arrange
        ApexClassModel.Definition definition = new ApexClassModel.Definition(ScheduleService.class);
        
        ScheduleStepConfig__c config = new ScheduleStepConfig__c(
            Name = '1#Test#1',
            IsActive__c = true,
            Is1200__c = true
        );
        insert config;
        
        //arrange
        Map<String,Object> inputEvent = new Map<String,Object>{
            'RecordId' => '08e000000000000AAA', //was heartbeat = true
            'StepConfigId' => config.Id,
            'EntryPointTimestamp' => System.now()
        };
        
        //act
        Test.startTest();
        Integer chunks = definition.Chunks;
        Integer counter = 0;
        for (Integer i = 0; i < chunks; i++) {
            ApexClassModel service = new ApexClassModel(ScheduleService.class);
            List<Map<String,Object>> outputs = service.invokeExecute(inputEvent);
            counter++;
        }
        Test.stopTest();

        //assert
        System.assertEquals(chunks, counter, 'Chunks not reached.');
    }
    
   /*static testmethod void withinSystemLimits() {
        //arrange
        ApexClassModel.Definition definition = new ApexClassModel.Definition(ScheduleService.class);
        
        ScheduleStepConfig__c config = new ScheduleStepConfig__c(
            IsActive__c = true,
            Frequency__c = 'Weekly',
            FriendlyDates__c = 'Wednesday',
            FriendlyTimes__c = '12:00'
        );
        insert config;
        
        //arrange
        Map<String,Object> inputEvent = new Map<String,Object>{
            'RecordId' => '08e000000000000AAA', //was heartbeat = true
            'StepConfigId' => config.Id,
            'EntryPointTimestamp' => System.now()
        };
        
        //act
        Test.startTest();
        Integer chunks = definition.Chunks;
        Integer counter = 0;
        for (Integer i = 0; i < chunks; i++) {
            ApexClassModel service = new ApexClassModel(ScheduleService.class);
            List<Map<String,Object>> outputs = service.invokeExecute(inputEvent);
            counter++;
        }
        Test.stopTest();

        //assert
        System.assertEquals(chunks, counter, 'Chunks not reached.');
   }*/

    
    static testmethod void messagePassedThruUntouchedWhenIsHeartbeatEqFalse() {
        //arrange input event
        Map<String,Object> inputEvent = new Map<String,Object>{
            'RecordId' => '00D000000000000AAA', //was heartbeat true
            'StepConfigId' => 'a01000000000000AAA',
            'EntryPointTimestamp' => System.now() //#810
        };
        
        //act
        ApexClassModel service = new ApexClassModel(ScheduleService.class);
        List<Map<String,Object>> outputEvents = service.invokeExecute(inputEvent);
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
    }
    
    static testmethod void messagePassedThruUntouchedWhenIsHeartbeatEqTrueAndIsWithinWindowReturnsTrue01() {
        //arrange config
        insert new ScheduleStepConfig__c(
            Name = '1#Test#1',
            IsActive__c = true,
            Is1200__c = true
        );

        //arrange input
        Datetime entryPoint = Datetime.newInstanceGmt(2014, 1, 15, 12, 0, 0); //15th Jan 2014 is a Wednesday
        Map<String,Object> inputEvent = new Map<String,Object>{
            'RecordId' => '08e000000000000AAA', //was heartbeat = true
            'StepConfigId' => [SELECT Id FROM ScheduleStepConfig__c].Id,
            'EntryPointTimestamp' => entryPoint
        };
        
        //act
        ApexClassModel service = new ApexClassModel(ScheduleService.class);
        List<Map<String,Object>> outputEvents = service.invokeExecute(inputEvent);
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
        
        String expectedEntryPoint = '2014-01-15T12:00:00.000Z';
        String actualEntryPoint = (String)outputEvents[0].get('EntryPointTimestamp');
        System.assertEquals(expectedEntryPoint, actualEntryPoint, 'Wrong entry point datetime.');
    }
    
    /*static testmethod void messagePassedThruUntouchedWhenIsHeartbeatEqTrueAndIsWithinWindowReturnsTrue01() {
        //arrange config
        insert new ScheduleStepConfig__c(
            IsActive__c = true,
            Frequency__c = 'Weekly',
            FriendlyDates__c = 'Wednesday',
            FriendlyTimes__c = '12:00'
        );

        //arrange input
        Datetime entryPoint = Datetime.newInstanceGmt(2014, 1, 15, 12, 0, 0); //15th Jan 2014 is a Wednesday
        Map<String,Object> inputEvent = new Map<String,Object>{
            'RecordId' => '08e000000000000AAA', //was heartbeat = true
            'StepConfigId' => [SELECT Id FROM ScheduleStepConfig__c].Id,
            'EntryPointTimestamp' => entryPoint
        };
        
        //act
        ApexClassModel service = new ApexClassModel(ScheduleService.class);
        List<Map<String,Object>> outputEvents = service.invokeExecute(inputEvent);
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
        
        String expectedEntryPoint = '2014-01-15T12:00:00.000Z';
        String actualEntryPoint = (String)outputEvents[0].get('EntryPointTimestamp');
        System.assertEquals(expectedEntryPoint, actualEntryPoint, 'Wrong entry point datetime.');
    }*/

    static testmethod void messagePassedThruUntouchedWhenIsHeartbeatEqTrueAndIsWithinWindowReturnsTrue02() {
        //arrange config
        insert new ScheduleStepConfig__c(
            Name = '1#Test#1',
            IsActive__c = true,
            Is1200__c = true
        );
        
        //arrange input
        Datetime entryPoint = Datetime.newInstanceGmt(2014, 1, 15, 12, 0, 0); //15th Jan 2014 is a Wednesday, a working day
        Map<String,Object> inputEvent = new Map<String,Object>{
            'RecordId' => '08e000000000000AAA', //was heartbeat = true
            'StepConfigId' => [SELECT Id FROM ScheduleStepConfig__c].Id,
            'EntryPointTimestamp' => entryPoint
        };
        
        ///act on working days only
        ApexClassModel service = new ApexClassModel(ScheduleService.class);
        List<Map<String,Object>> outputEvents = service.invokeExecute(inputEvent);
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
        
        String expectedEntryPoint = '2014-01-15T12:00:00.000Z';
        String actualEntryPoint = (String)outputEvents[0].get('EntryPointTimestamp');
        System.assertEquals(expectedEntryPoint, actualEntryPoint, 'Wrong entry point datetime.');
    }
    
    /*static testmethod void messagePassedThruUntouchedWhenIsHeartbeatEqTrueAndIsWithinWindowReturnsTrue02() {
        //arrange config
        insert new ScheduleStepConfig__c(
            IsActive__c = true,
            Frequency__c = 'Daily',
            FriendlyDates__c = 'Working days only',
            FriendlyTimes__c = '12:00'
        );
        
        //arrange input
        Datetime entryPoint = Datetime.newInstanceGmt(2014, 1, 15, 12, 0, 0); //15th Jan 2014 is a Wednesday, a working day
        Map<String,Object> inputEvent = new Map<String,Object>{
            'RecordId' => '08e000000000000AAA', //was heartbeat = true
            'StepConfigId' => [SELECT Id FROM ScheduleStepConfig__c].Id,
            'EntryPointTimestamp' => entryPoint
        };
        
        ///act on working days only
        ApexClassModel service = new ApexClassModel(ScheduleService.class);
        List<Map<String,Object>> outputEvents = service.invokeExecute(inputEvent);
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
        
        String expectedEntryPoint = '2014-01-15T12:00:00.000Z';
        String actualEntryPoint = (String)outputEvents[0].get('EntryPointTimestamp');
        System.assertEquals(expectedEntryPoint, actualEntryPoint, 'Wrong entry point datetime.');
    }*/
    
    static testmethod void messagePassedThruUntouchedWhenIsHeartbeatEqTrueAndIsWithinWindowReturnsTrue03() {
        //arrange config
        insert new ScheduleStepConfig__c(
            Name = '1#Test#1',
            IsActive__c = true,
            Is1200__c = true
        );
        
        //arrange input
        Datetime entryPoint = Datetime.newInstanceGmt(2014, 1, 3, 12, 0, 0);
        Map<String,Object> inputEvent = new Map<String,Object>{
            'RecordId' => '08e000000000000AAA', //was heartbeat = true
            'StepConfigId' => [SELECT Id FROM ScheduleStepConfig__c].Id,
            'EntryPointTimestamp' => entryPoint
        };
 
        //act
        ApexClassModel service = new ApexClassModel(ScheduleService.class);
        List<Map<String,Object>> outputEvents = service.invokeExecute(inputEvent);
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
        
        String expectedEntryPoint = '2014-01-03T12:00:00.000Z';
        String actualEntryPoint = (String)outputEvents[0].get('EntryPointTimestamp');
        System.assertEquals(expectedEntryPoint, actualEntryPoint, 'Wrong entry point datetime.');
    }
    
    /*static testmethod void messagePassedThruUntouchedWhenIsHeartbeatEqTrueAndIsWithinWindowReturnsTrue03() {
        //arrange config
        insert new ScheduleStepConfig__c(
            IsActive__c = true,
            Frequency__c = 'Monthly',
            FriendlyDates__c = '03;15;16',
            FriendlyTimes__c = '12:00'
        );
        
        //arrange input
        Datetime entryPoint = Datetime.newInstanceGmt(2014, 1, 3, 12, 0, 0);
        Map<String,Object> inputEvent = new Map<String,Object>{
            'RecordId' => '08e000000000000AAA', //was heartbeat = true
            'StepConfigId' => [SELECT Id FROM ScheduleStepConfig__c].Id,
            'EntryPointTimestamp' => entryPoint
        };
 
        //act
        ApexClassModel service = new ApexClassModel(ScheduleService.class);
        List<Map<String,Object>> outputEvents = service.invokeExecute(inputEvent);
        
        //assert
        Integer expectedSize = 1;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
        
        String expectedEntryPoint = '2014-01-03T12:00:00.000Z';
        String actualEntryPoint = (String)outputEvents[0].get('EntryPointTimestamp');
        System.assertEquals(expectedEntryPoint, actualEntryPoint, 'Wrong entry point datetime.');
    }*/
    
    static testmethod void messageSwallowedWhenIsHeartbeatEqTrueAndIsWithinWindowReturnsFalse() {
        //arrange config
        insert new ScheduleStepConfig__c(
            Name = '1#Test#1',
            IsActive__c = true,
            //Frequency__c = 'Weekly',
            Is1300__c = true
        );
        
        //arrange input event parameters
        Datetime entryPoint = Datetime.newInstanceGmt(2014, 1, 18, 12, 0, 0);
        Map<String,Object> inputEvent = new Map<String,Object>{
            'RecordId' => '08e000000000000AAA', //was heartbeat = true
            'StepConfigId' => [SELECT Id FROM ScheduleStepConfig__c].Id,
            'EntryPointTimestamp' => entryPoint
        };
 
        //act
        ApexClassModel service = new ApexClassModel(ScheduleService.class);
        List<Map<String,Object>> outputEvents = service.invokeExecute(inputEvent);
        
        //assert
        Integer expectedSize = 0;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
    }
    
    /*static testmethod void messageSwallowedWhenIsHeartbeatEqTrueAndIsWithinWindowReturnsFalse() {
        //arrange config
        insert new ScheduleStepConfig__c(
            Frequency__c = 'Weekly',
            FriendlyDates__c = 'Wednesday',
            FriendlyTimes__c = '13:00'
        );
        
        //arrange input event parameters
        Datetime entryPoint = Datetime.newInstanceGmt(2014, 1, 18, 12, 0, 0);
        Map<String,Object> inputEvent = new Map<String,Object>{
            'RecordId' => '08e000000000000AAA', //was heartbeat = true
            'StepConfigId' => [SELECT Id FROM ScheduleStepConfig__c].Id,
            'EntryPointTimestamp' => entryPoint
        };
 
        //act
        ApexClassModel service = new ApexClassModel(ScheduleService.class);
        List<Map<String,Object>> outputEvents = service.invokeExecute(inputEvent);
        
        //assert
        Integer expectedSize = 0;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');
    }*/
    
    static testmethod void isHeartbeatThrowsExceptionWhenInvalidStampParam() {
        //arrange config
        insert new ScheduleStepConfig__c(
            Name = '1#Test#1',
            IsActive__c = true
        );
        
        //arrange input
        Datetime entryPoint = null;
        Map<String,Object> inputEvent = new Map<String,Object>{
            'RecordId' => '08e000000000000AAA', //was heartbeat = true
            'StepConfigId' => [SELECT Id FROM ScheduleStepConfig__c].Id,
            'EntryPointTimestamp' => entryPoint
        };
        
        try {
            //act
            ApexClassModel service = new ApexClassModel(ScheduleService.class);
            service.invokeExecute(inputEvent);
            System.assert(false, 'Line above should throw exception.');
        } catch (ScheduleService.ServiceException e) {
            //assert
            String expectedMessage = 'Null entry point timestamp.';
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
        System.assert(ScheduleService.isTimeMatch(stampAsString1, runTimesA));
        System.assert(ScheduleService.isTimeMatch(stampAsString1, runTimesA));
        System.assert(ScheduleService.isTimeMatch(stampAsString1, runTimesA));
        System.assert(ScheduleService.isTimeMatch(stampAsString1, runTimesB));
        System.assert(ScheduleService.isTimeMatch(stampAsString1, runTimesB));
        System.assert(ScheduleService.isTimeMatch(stampAsString1, runTimesB));
    }
    
}