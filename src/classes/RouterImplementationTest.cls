@IsTest private class RouterImplementationTest {
 
    static testMethod void callingGetInitialStampReturnsExpectedStampForIntervalOf60() {
        // arrange
        Integer  hour = 03;
        Integer  minute = 22;
        Integer  second = 07;
        Time currentTime = Time.newInstance(hour, minute, second, 0);
        DateTime currentDateTime = DateTime.newInstance(2014,12,16, hour, minute, second);
        
        Integer intervalInMinutes = 60;
        
        // act
        DateTime actualInitialStamp = RouterImplementation.getInitialStamp(intervalInMinutes, currentDateTime);

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
        DateTime actualInitialStampA = RouterImplementation.getInitialStamp(intervalInMinutes, currentDateTimeA);
        DateTime actualInitialStampB = RouterImplementation.getInitialStamp(intervalInMinutes, currentDateTimeB);
        DateTime actualInitialStampC = RouterImplementation.getInitialStamp(intervalInMinutes, currentDateTimeC);
        
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
        DateTime actualInitialStampA = RouterImplementation.getInitialStamp(intervalInMinutes, currentDateTimeA);
        DateTime actualInitialStampB = RouterImplementation.getInitialStamp(intervalInMinutes, currentDateTimeB);
        DateTime actualInitialStampC = RouterImplementation.getInitialStamp(intervalInMinutes, currentDateTimeC);
        
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
        List<DateTime> actualHeartbeats = RouterImplementation.getHeartbeats(intervalInMinutes, lastEventStamp, currentDateTime);

        // assemble
        Integer actualCount  = actualHeartbeats.size();
        DateTime actualStamp = null;
        if (actualCount > 0) {
            actualStamp = actualHeartbeats[0];
        }

        // assert
        Integer expectedCount  = 1;
        System.assertEquals(expectedCount, actualCount);
        
        DateTime expectedStamp = RouterImplementation.getInitialStamp(intervalInMinutes, currentDateTime);
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
        List<DateTime> actualHeartbeats = RouterImplementation.getHeartbeats(intervalInMinutes, lastEventStamp, currentDateTime);

        // assemble
        DateTime endEventStamp = RouterImplementation.getInitialStamp(intervalInMinutes, currentDateTime);
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
        RouterImplementation.updateLastEventStamp( heartbeats );

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
        RouterImplementation.updateLastEventStamp( heartbeats );

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
        RouterImplementation.generateHeartbeats(intervalInMinutes, lastEventStamp, currentDateTime);
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
        RouterImplementation.IHeartbeatGenerator heartbeatGeneratorMock = (RouterImplementation.IHeartbeatGenerator)
            new RouterImplementation.HeartbeatGeneratorMock(
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
    
    @TestVisible private class ToolingApiResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('{"success":true}');
            return response;
        }
    }
  
    
    // @testSetUp
    // static private void setUpBritishSummerTimeUser() {
    //     User user = new User (
    //         Alias = 'Test',
    //         UserName = 'test@14333esb47969.com',
    //         FirstName = 'Test',
    //         LastName = 'Test',
    //         Email = 'test@14333esb47969.com',
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
    //     PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'AdministerEsb'];
    //     insert new PermissionSetAssignment(AssigneeId = user.Id, PermissionSetId = ps.Id);
    // }
}