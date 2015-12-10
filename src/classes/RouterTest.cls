/**
 * @Obfuscation
 * Formerly nown as HeartbeatTest
 */
@IsTest class RouterTest {
    
    @TestSetup static void testSetup() {
        //act
        upsert BrokerSetting__c.getOrgDefaults();
        
        //assert
        System.assertNotEquals(null, BrokerSetting__c.getOrgDefaults().Id, 'Wrong id.');
    }
    
    static testmethod void testHeartbeatDispatchesOneIndexedMessages() {
        //arrange services, sequence, step
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        Step__c scheduleStep = SequenceModel.fromName(sequence.Name).appendStep(ScheduleDaily.class);
        
        //arrange input event
        Map<String,Object> inputEvent = new Map<String,Object>{
            'EntryPointTimestamp' => '2014-01-18T12:00:00.000Z'
        };
        
        //act
        ApexClassModel.Service service = new Router();
        List<Map<String,Object>> outputs = service.handle(inputEvent);
        
        //assert
        Integer expectedSize = 1; //one schedule
        Integer actualSize = outputs.size();
        System.assertEquals(expectedSize, actualSize, 'Should have one output.');
        
        //assemble
        Map<String,Object> output = outputs[0];
        
        //assert
        String expectedSequence = '1#Test#0';
        String actualSequence = (String)output.get('Route');
        System.assertEquals(expectedSequence, actualSequence, 'Wrong sequence.');
    }

    static testmethod void noInterestedServicesReturnsZeroMessages() {
        //arrange input event
        String stampAsString = '2014-01-18T12:00:00.000Z';
        Map<String,Object> inputEvent = new Map<String,Object>{
            'EntryPointTimestamp' => stampAsString
        };

        //act
        ApexClassModel.Service service = new Router();
        List<Map<String,Object>> outputEvents = service.handle(inputEvent);

        //assert
        Integer expectedSize = 0;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize);
    }


    static testmethod void  gtOneInterestedServiceReturnsSameNumberOfMessages() {
        //arrange sequence
        Sequence__c interestedSequenceA = new Sequence__c(Name = 'InterestedSequenceA');
        insert interestedSequenceA;
        Sequence__c interestedSequenceB = new Sequence__c(Name = 'InterestedSequenceB');
        insert interestedSequenceB;

        //arrange steps
        Step__c stepA = SequenceModel.fromName(interestedSequenceA.Name).appendStep(ScheduleDaily.class);
        Step__c stepB = SequenceModel.fromName(interestedSequenceB.Name).appendStep(ScheduleDaily.class);
        
        //arrange events
        String stampAsString = '2014-01-18T12:00:00.000Z';
        Map<String,Object> inputEvent = new Map<String,Object>{
            'EntryPointTimestamp' => stampAsString
        };

        //act
        ApexClassModel.Service service = new Router();
        List<Map<String,Object>> outputEvents = service.handle(inputEvent);

        //assert
        Integer expectedSize = 2;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize);
    }

    // @TestSetup
    // static void setUpBritishSummerTimeUser() {
    //     User user = new User (
    //         Alias = 'Test',
    //         UserName = 'test@14333servicebus47969.com',
    //         FirstName = 'Test',
    //         LastName = 'Test',
    //         Email = 'test@14333servicebus47969.com',
    //         ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id,
    //         EmailEncodingKey = 'UTF-8',
    //         LanguageLocaleKey = 'en_US',
    //         LocaleSidKey = 'en_US',
    //         TimeZoneSidKey = 'Europe/London'    // British Summer Time (Europe/London) ,  'America/Los_Angeles' , etc
    //     );
    //
    //
    //     insert user;
    //
    //     PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'AdministerServiceBus'];
    //     insert new PermissionSetAssignment(AssigneeId = user.Id, PermissionSetId = ps.Id);
    // }

    static testMethod void callingGetInitialStampReturnsExpectedStampForIntervalOf60() {
        // arrange
        Integer  hour = 03;
        Integer  minute = 22;
        Integer  second = 07;
        Time currentTime = Time.newInstance(hour, minute, second, 0);
        DateTime currentDateTime = DateTime.newInstance(2014,12,16, hour, minute, second);
        
        Integer intervalInMinutes = 60;
        
        // act
        DateTime actualInitialStamp = Router.getInitialStamp(intervalInMinutes, currentDateTime);

        // assert
        DateTime expectedInitialStamp = DateTime.newInstance(2014,12,16, hour, 0, 0);
        System.assertEquals(expectedInitialStamp, actualInitialStamp);
    }

 
    static testMethod void callingGetInitialStampReturnsExpectedStampForIntervalOf15() {
        // arrange
        Integer  hour = 03;
        Integer  second = 07;
        
        Integer  minuteA = 22;
        DateTime currentDateTimeA = DateTime.newInstance(2014,12,16, hour, minuteA, second);
        
        Integer  minuteB = 34;
        DateTime currentDateTimeB = DateTime.newInstance(2014,12,16, hour, minuteB, second);
        
        Integer  minuteC = 45;
        DateTime currentDateTimeC = DateTime.newInstance(2014,12,16, hour, minuteC, second);
        
        Integer intervalInMinutes = 15;
        
        // act
        DateTime actualInitialStampA = Router.getInitialStamp(intervalInMinutes, currentDateTimeA);
        DateTime actualInitialStampB = Router.getInitialStamp(intervalInMinutes, currentDateTimeB);
        DateTime actualInitialStampC = Router.getInitialStamp(intervalInMinutes, currentDateTimeC);
        
        // assert
        // minute : 22 --> 15
        Integer expectedMinuteA = 15;
        DateTime expectedInitialStampA = DateTime.newInstance(2014,12,16, hour, expectedMinuteA, 0);
        System.assertEquals(expectedInitialStampA, actualInitialStampA);

       // minute : 34 --> 30
       Integer expectedMinuteB = 30;
       DateTime expectedInitialStampB = DateTime.newInstance(2014,12,16, hour, expectedMinuteB, 0);
       System.assertEquals(expectedInitialStampB, actualInitialStampB);
       
       // minute : 45 --> 45
       Integer expectedMinuteC = 45;
       ////Time expectedInitialTimeC = Time.newInstance(hour, expectedMinuteC, 0, 0);
       DateTime expectedInitialStampC = DateTime.newInstance(2014,12,16, hour, expectedMinuteC, 0);
       System.assertEquals(expectedInitialStampC, actualInitialStampC);
    }

 
    static testMethod void callingGetInitialStampReturnsExpectedStampForIntervalOf05() {
        // arrange
        Integer  hour = 03;
        Integer  second = 07;
        
        Integer  minuteA = 03;
        DateTime currentDateTimeA = DateTime.newInstance(2014,12,16, hour, minuteA, second);
        
        Integer  minuteB = 12;
        DateTime currentDateTimeB = DateTime.newInstance(2014,12,16, hour, minuteB, second);
        
        Integer  minuteC = 45;
        DateTime currentDateTimeC = DateTime.newInstance(2014,12,16, hour, minuteC, second);
        
        Integer intervalInMinutes = 05;
        
        // act
        DateTime actualInitialStampA = Router.getInitialStamp(intervalInMinutes, currentDateTimeA);
        DateTime actualInitialStampB = Router.getInitialStamp(intervalInMinutes, currentDateTimeB);
        DateTime actualInitialStampC = Router.getInitialStamp(intervalInMinutes, currentDateTimeC);
        
        // assert
        // minute : 03 --> 00
        Integer expectedMinuteA = 00;
        DateTime expectedInitialStampA = DateTime.newInstance(2014,12,16, hour, expectedMinuteA, 0);
        System.assertEquals(expectedInitialStampA, actualInitialStampA);

       // minute : 12 --> 10
       Integer expectedMinuteB = 10;
       DateTime expectedInitialStampB = DateTime.newInstance(2014,12,16, hour, expectedMinuteB, 0);
       System.assertEquals(expectedInitialStampB, actualInitialStampB);
       
       // minute : 45 --> 45
       Integer expectedMinuteC = 45;
       DateTime expectedInitialStampC = DateTime.newInstance(2014,12,16, hour, expectedMinuteC, 0);
       System.assertEquals(expectedInitialStampC, actualInitialStampC);
    }


    static testMethod void callingGetHeartbeatsReturnsExpectedHeartbeatCollectionWhenLastEventStampEqNull() {
        // arrange
        Integer  hour   = 03;
        Integer  second = 07;
        Integer  minute = 03;

        DateTime currentDateTime = DateTime.newInstance(2014,12,16, hour, minute, second);
        DateTime lastEventStamp = null;
        Integer intervalInMinutes = 05;

        // act
        List<DateTime> actualHeartbeats = Router.getHeartbeats(intervalInMinutes, lastEventStamp, currentDateTime);

        // assemble
        Integer actualCount  = actualHeartbeats.size();
        DateTime actualStamp = null;
        if (actualCount > 0) {
            actualStamp = actualHeartbeats[0];
        }

        // assert
        Integer expectedCount  = 1;
        System.assertEquals(expectedCount, actualCount);
        
        DateTime expectedStamp = Router.getInitialStamp(intervalInMinutes, currentDateTime);
        System.assertEquals(expectedStamp, actualStamp);
    }

 
    static testMethod void callingGetHeartbeatsReturnsExpectedHeartbeatCollectionWhenLastEventStampIsNotNull() {
        // arrange
        Integer intervalInMinutes = 05;
                
        Date currentDate = Date.newInstance(2014,12,16);
        
        Integer  hour   = 03;
        Integer  second = 07;
        Integer  minute = 42;
        DateTime currentDateTime = DateTime.newInstance(2014,12,16, hour, minute, second);

        Integer lastEventMinute = 00;
        DateTime lastEventStamp =  DateTime.newInstance(2014,12,16, hour, lastEventMinute, 00);

        // act
        List<DateTime> actualHeartbeats = Router.getHeartbeats(intervalInMinutes, lastEventStamp, currentDateTime);

        // assemble
        DateTime endEventStamp = Router.getInitialStamp(intervalInMinutes, currentDateTime);
        Set<DateTime> actualHeartbeatsAsSet =  new Set<DateTime>(actualHeartbeats);
        Integer actualCount  = actualHeartbeats.size();
        
        Set<DateTime> expectedHeartbeatsAsSet =  new Set<DateTime>{
            DateTime.newInstance(2014,12,16, hour, 05, 00),
            DateTime.newInstance(2014,12,16, hour, 10, 00),
            DateTime.newInstance(2014,12,16, hour, 15, 00),
            DateTime.newInstance(2014,12,16, hour, 20, 00),
            DateTime.newInstance(2014,12,16, hour, 25, 00),
            DateTime.newInstance(2014,12,16, hour, 30, 00),
            DateTime.newInstance(2014,12,16, hour, 35, 00),
            DateTime.newInstance(2014,12,16, hour, 40, 00)
        };
        Integer expectedCount  = expectedHeartbeatsAsSet.size();
 
        Boolean actualFlagA = true;
        for (DateTime expectedHeartbeat : expectedHeartbeatsAsSet) {
            if (!actualHeartbeatsAsSet.contains(expectedHeartbeat))
                actualFlagA = false;
        }
 
        Boolean actualFlagB = (!actualHeartbeatsAsSet.contains(lastEventStamp));
 

        // assert
        System.assertEquals(expectedCount, actualCount);
        
        Boolean expectedFlagA = true;
        System.assertEquals(expectedFlagA, actualFlagA);
        
        Boolean expectedFlagB = true;
        System.assertEquals(expectedFlagB, actualFlagB);
    }

 
    static testMethod void callingGetHeartbeatsCorrectlyUpdatesLastEventStampSettingWhenHeartbeatsCollectionIsEmpty() {
        // arrange
        List<DateTime> heartbeats = new List<DateTime>();

        // act
        Router.updateLastEventStamp( heartbeats );

        // assemble
        BrokerSetting__c settings = BrokerSetting__c.getOrgDefaults();
        DateTime actualEventStamp =  settings.EventTimestamp__c;
        
        // assert
        DateTime expectedEventStamp = null;
        System.assertEquals(expectedEventStamp, actualEventStamp);
    }


 
    static testMethod void callingGetHeartbeatsCorrectlyUpdatesLastEventStampSettingWhenHeartbeatsCollectionIsNotEmpty() {
        // arrange
        Integer year = 2014;
        Integer month = 12;
        Integer day = 16;
        DateTime stampA = DateTime.newInstance(year,month,day,13, 05, 00);
        DateTime stampB = DateTime.newInstance(year,month,day,13, 10, 00);
        DateTime stampC = DateTime.newInstance(year,month,day,13, 15, 00);
         
        List<DateTime> heartbeats = new List<DateTime>{
            stampA,
            stampB,
            stampC
        };

        // act
        Router.updateLastEventStamp( heartbeats );

        // assemble
        BrokerSetting__c settings = BrokerSetting__c.getOrgDefaults();
        DateTime actualEventStamp = settings.EventTimestamp__c;
        
        // assert
        DateTime expectedEventStamp =  stampC;
        System.assertEquals(expectedEventStamp, actualEventStamp);
    }

 
    static testMethod void callingGenerateHeartbeatsInsertsExpectedMessages() {
        // arrange
        Integer intervalInMinutes = 05;
        
        Integer  hour   = 03;
        Integer  second = 07;
        Integer  minute = 42;
        DateTime currentDateTime = DateTime.newInstanceGmt(2014,12,16, hour, minute, second);
        
        Integer lastEventMinute = 00;
        DateTime lastEventStamp =  DateTime.newInstanceGmt(2014,12,16, hour, lastEventMinute, 00);
        
        // act
        Test.startTest();
        Router.generateHeartbeats(intervalInMinutes, lastEventStamp, currentDateTime);
        Test.stopTest();
        
        //assemble 1
        List<Message__c> messages = [
            SELECT Id, Event__c
            FROM Message__c
        ];
        
        //assert 1
        Integer expectedSize = 8;
        Integer actualSize = messages.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong count.');

        //assemble 2
        Set<DateTime> expectedHeartbeatsAsSet = new Set<DateTime>{
             DateTime.newInstanceGmt(2014,12,16,  hour, 05, 00 ),
             DateTime.newInstanceGmt(2014,12,16,  hour, 10, 00 ),
             DateTime.newInstanceGmt(2014,12,16,  hour, 15, 00 ),
             DateTime.newInstanceGmt(2014,12,16,  hour, 20, 00 ),
             DateTime.newInstanceGmt(2014,12,16,  hour, 25, 00 ),
             DateTime.newInstanceGmt(2014,12,16,  hour, 30, 00 ),
             DateTime.newInstanceGmt(2014,12,16,  hour, 35, 00 ),
             DateTime.newInstanceGmt(2014,12,16,  hour, 40, 00 )
        };

        Set<DateTime> actualHeartbeatsAsSet =  new Set<DateTime>();
        Boolean actualFlag = true;
        for (Message__c message : messages) {
          Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(message.Event__c);
          DateTime actualEventStamp = (DateTime)Json.deserialize('"' + ((String)parameters.get('EntryPointTimestamp')) + '"', DateTime.class);
          actualHeartbeatsAsSet.add(actualEventStamp);
          if (!expectedHeartbeatsAsSet.contains(actualEventStamp))
                actualFlag = false;
        }

        List<String> expectedHeartbeatsAsStringSet =  new List<String>();
        List<String> actualHeartbeatsAsStringSet =  new List<String>();
        for (DateTime heartbeat : actualHeartbeatsAsSet) {
            actualHeartbeatsAsStringSet.add(json.serialize(heartbeat));
        }
        for (DateTime heartbeat : expectedHeartbeatsAsSet) {
            expectedHeartbeatsAsStringSet.add(json.serialize(heartbeat));
        }
        actualHeartbeatsAsStringSet.sort();
        expectedHeartbeatsAsStringSet.sort();

        // assert 2
        system.assertEquals(json.serialize(expectedHeartbeatsAsStringSet) , json.serialize(actualHeartbeatsAsStringSet));
    }

 
 
    static testMethod void callingGenerateHeartbeatsViaInterfaceInsertsExpectedMessages() {
        // arrange
        Integer intervalInMinutes = 05;

        Integer  hour   = 03;
        Integer  second = 07;
        Integer  minute = 42;
        DateTime currentDateTime = DateTime.newInstanceGmt(2014,12,16, hour, minute, second);
        
        Integer lastEventMinute = 00;
        DateTime lastEventStamp =  DateTime.newInstanceGmt(2014,12,16, hour, lastEventMinute, 00);
        
        // act
        Router.IHeartbeatGenerator heartbeatGeneratorMock = (Router.IHeartbeatGenerator)
            new Router.HeartbeatGeneratorMock(
                intervalInMinutes,
                lastEventStamp,
                currentDateTime
            );

        Test.startTest();
        heartbeatGeneratorMock.generateHeartbeats();
        Test.stopTest();
        
        //assemble 1
        List<Message__c> messages = [
            SELECT Id, Event__c
            FROM Message__c
        ];
        
        //assert 1
        Integer expectedSize = 8;
        Integer actualSize = messages.size();
        System.assertEquals(expectedSize, actualSize, 'Wrong size.');

        // assemble 2
        Set<DateTime> expectedHeartbeatsAsSet =  new Set<DateTime>{
             DateTime.newInstanceGmt(2014,12,16, hour, 05, 00),
             DateTime.newInstanceGmt(2014,12,16, hour, 10, 00),
             DateTime.newInstanceGmt(2014,12,16, hour, 15, 00),
             DateTime.newInstanceGmt(2014,12,16, hour, 20, 00),
             DateTime.newInstanceGmt(2014,12,16, hour, 25, 00),
             DateTime.newInstanceGmt(2014,12,16, hour, 30, 00),
             DateTime.newInstanceGmt(2014,12,16, hour, 35, 00),
             DateTime.newInstanceGmt(2014,12,16, hour, 40, 00)
        };
        
        Set<DateTime> actualHeartbeatsAsSet =  new Set<DateTime>();
        Boolean actualFlag = true;
        for (Message__c message : messages) {
            Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(message.Event__c);
            DateTime actualEventStamp = (DateTime)Json.deserialize('"' + ((String)parameters.get('EntryPointTimestamp')) + '"', DateTime.class);
            actualHeartbeatsAsSet.add(actualEventStamp);
            if (!expectedHeartbeatsAsSet.contains(actualEventStamp))
                actualFlag = false;
        }


        List<String> expectedHeartbeatsAsStringSet =  new List<String>();
        List<String> actualHeartbeatsAsStringSet =  new List<String>();
        for (DateTime heartbeat : actualHeartbeatsAsSet) {
            actualHeartbeatsAsStringSet.add(json.serialize(heartbeat));
        }
        for (DateTime heartbeat : expectedHeartbeatsAsSet) {
            expectedHeartbeatsAsStringSet.add(json.serialize(heartbeat));
        }
        actualHeartbeatsAsStringSet.sort();
        expectedHeartbeatsAsStringSet.sort();
        
        // assert 2
        system.assertEquals(json.serialize(expectedHeartbeatsAsStringSet) , json.serialize(actualHeartbeatsAsStringSet));
    }
    
    @TestVisible class ToolingApiResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('{"success":true}');
            return response;
        }
    }
    
    static testmethod void testRetryStartedMessages() {
        //arrange with retry
        insert new Message__c(
            Status__c = 'Started',
            Exception__c = 'With retry',
            Attempts__c = 1,
            IsRetryable__c = true
        );
        
        //arrange sans retry
        insert new Message__c(
            Status__c = 'Started',
            Exception__c = 'Sans retry',
            Attempts__c = 1,
            IsRetryable__c = false
        );
        
        //act
        new Router().retryStartedMessages();
        
        //assert
        Integer expectedCount = 1;
        Integer actualCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Buffered'];
        System.assertEquals(expectedCount, actualCount, 'Wrong count.');
    }
}