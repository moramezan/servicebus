@IsTest private class HeartbeatImplementationTest {
 
    static testMethod void callingGetInitialStampReturnsExpectedStampForIntervalOf60() {
        // arrange 
        Date currentDate = Date.newInstance(2014,12,16);
        Integer  hour = 03;
        Integer  minute = 22;
        Integer  second = 07;
        Time currentTime = Time.newInstance(hour, minute, second, 0);
        DateTime currentDateTime = DateTime.newInstance(currentDate, currentTime);
        
        Integer intervalInMinutes = 60;
        
        // act
        DateTime actualInitialStamp = HeartbeatImplementation.getInitialStamp(intervalInMinutes, currentDateTime);
        
        // assert
        Time expectedInitialTime = Time.newInstance(hour, 0, 0, 0);
        DateTime expectedInitialStamp = DateTime.newInstance(currentDate, expectedInitialTime);
        System.assertEquals(expectedInitialStamp, actualInitialStamp);
    }

 
    static testMethod void callingGetInitialStampReturnsExpectedStampForIntervalOf15() {
        // arrange 
        Date currentDate = Date.newInstance(2014,12,16);
        Integer  hour = 03;
        Integer  second = 07;
        
        Integer  minuteA = 22;
        Time currentTimeA = Time.newInstance(hour, minuteA, second, 0);
        DateTime currentDateTimeA = DateTime.newInstance(currentDate, currentTimeA);
        
        Integer  minuteB = 34; 
        Time currentTimeB = Time.newInstance(hour, minuteB, second, 0);
        DateTime currentDateTimeB = DateTime.newInstance(currentDate, currentTimeB);
        
        Integer  minuteC = 45; 
        Time currentTimeC = Time.newInstance(hour, minuteC, second, 0);
        DateTime currentDateTimeC = DateTime.newInstance(currentDate, currentTimeC);
        
        Integer intervalInMinutes = 15;
        
        // act
        DateTime actualInitialStampA = HeartbeatImplementation.getInitialStamp(intervalInMinutes, currentDateTimeA);
        DateTime actualInitialStampB = HeartbeatImplementation.getInitialStamp(intervalInMinutes, currentDateTimeB);
        DateTime actualInitialStampC = HeartbeatImplementation.getInitialStamp(intervalInMinutes, currentDateTimeC);
        
        // assert
        // minute : 22 --> 15
        Integer expectedMinuteA = 15;
        Time expectedInitialTimeA = Time.newInstance(hour, expectedMinuteA, 0, 0);
        DateTime expectedInitialStampA = DateTime.newInstance(currentDate, expectedInitialTimeA);
        System.assertEquals(expectedInitialStampA, actualInitialStampA);

       // minute : 34 --> 30 
       Integer expectedMinuteB = 30;
       Time expectedInitialTimeB = Time.newInstance(hour, expectedMinuteB, 0, 0);
       DateTime expectedInitialStampB = DateTime.newInstance(currentDate, expectedInitialTimeB);
       System.assertEquals(expectedInitialStampB, actualInitialStampB);
       
       // minute : 45 --> 45
       Integer expectedMinuteC = 45;
       Time expectedInitialTimeC = Time.newInstance(hour, expectedMinuteC, 0, 0);
       DateTime expectedInitialStampC = DateTime.newInstance(currentDate, expectedInitialTimeC);
       System.assertEquals(expectedInitialStampC, actualInitialStampC);
    }

 
    static testMethod void callingGetInitialStampReturnsExpectedStampForIntervalOf05() {
        // arrange 
        Date currentDate = Date.newInstance(2014,12,16);
        Integer  hour = 03;
        Integer  second = 07;
        
        Integer  minuteA = 03;
        Time currentTimeA = Time.newInstance(hour, minuteA, second, 0);
        DateTime currentDateTimeA = DateTime.newInstance(currentDate, currentTimeA);
        
        Integer  minuteB = 12; 
        Time currentTimeB = Time.newInstance(hour, minuteB, second, 0);
        DateTime currentDateTimeB = DateTime.newInstance(currentDate, currentTimeB);
        
        Integer  minuteC = 45; 
        Time currentTimeC = Time.newInstance(hour, minuteC, second, 0);
        DateTime currentDateTimeC = DateTime.newInstance(currentDate, currentTimeC);
        
        Integer intervalInMinutes = 05;
        
        // act
        DateTime actualInitialStampA = HeartbeatImplementation.getInitialStamp(intervalInMinutes, currentDateTimeA);
        DateTime actualInitialStampB = HeartbeatImplementation.getInitialStamp(intervalInMinutes, currentDateTimeB);
        DateTime actualInitialStampC = HeartbeatImplementation.getInitialStamp(intervalInMinutes, currentDateTimeC);
        
        // assert
        // minute : 03 --> 00
        Integer expectedMinuteA = 00;
        Time expectedInitialTimeA = Time.newInstance(hour, expectedMinuteA, 0, 0);
        DateTime expectedInitialStampA = DateTime.newInstance(currentDate, expectedInitialTimeA);
        System.assertEquals(expectedInitialStampA, actualInitialStampA);

       // minute : 12 --> 10 
       Integer expectedMinuteB = 10;
       Time expectedInitialTimeB = Time.newInstance(hour, expectedMinuteB, 0, 0);
       DateTime expectedInitialStampB = DateTime.newInstance(currentDate, expectedInitialTimeB);
       System.assertEquals(expectedInitialStampB, actualInitialStampB);
       
       // minute : 45 --> 45
       Integer expectedMinuteC = 45;
       Time expectedInitialTimeC = Time.newInstance(hour, expectedMinuteC, 0, 0);
       DateTime expectedInitialStampC = DateTime.newInstance(currentDate, expectedInitialTimeC);
       System.assertEquals(expectedInitialStampC, actualInitialStampC);
    }

 
    static testMethod void callingGetHeartbeatsReturnsExpectedHeartbeatCollectionWhenLastEventStampEqNull() {
        // arrange 
        Date currentDate = Date.newInstance(2014,12,16);
        Integer  hour   = 03;
        Integer  second = 07;
        Integer  minute = 03;
        Time currentTime = Time.newInstance(hour, minute, second, 0);
        DateTime currentDateTime = DateTime.newInstance(currentDate, currentTime);
        DateTime lastEventStamp = null; 
        Integer intervalInMinutes = 05;

        // act
        List<DateTime> actualHeartbeats = HeartbeatImplementation.getHeartbeats(intervalInMinutes, lastEventStamp, currentDateTime);

        // assemble
        Integer actualCount  = actualHeartbeats.size();
        DateTime actualStamp = null;
        if (actualCount > 0) {
            actualStamp = actualHeartbeats[0];
        }

        // assert
        Integer expectedCount  = 1;
        System.assertEquals(expectedCount, actualCount);
        
        DateTime expectedStamp = HeartbeatImplementation.getInitialStamp(intervalInMinutes, currentDateTime);
        System.assertEquals(expectedStamp, actualStamp);
    } 

 
    static testMethod void callingGetHeartbeatsReturnsExpectedHeartbeatCollectionWhenLastEventStampIsNotNull() {
        // arrange 
        Integer intervalInMinutes = 05;
                
        Date currentDate = Date.newInstance(2014,12,16);
        
        Integer  hour   = 03;
        Integer  second = 07;
        Integer  minute = 42;
        Time currentTime = Time.newInstance(hour, minute, second, 0);
        DateTime currentDateTime = DateTime.newInstance(currentDate, currentTime);

        Integer lastEventMinute = 00;
        Time lastEventTime = Time.newInstance(hour, lastEventMinute, 00, 0);
        DateTime lastEventStamp =  DateTime.newInstance(currentDate, lastEventTime);

        // act
        List<DateTime> actualHeartbeats = HeartbeatImplementation.getHeartbeats(intervalInMinutes, lastEventStamp, currentDateTime);

        // assemble
        DateTime endEventStamp = HeartbeatImplementation.getInitialStamp(intervalInMinutes, currentDateTime); 
        Set<DateTime> actualHeartbeatsAsSet =  new Set<DateTime>(actualHeartbeats);
        Integer actualCount  = actualHeartbeats.size();
        
        Set<DateTime> expectedHeartbeatsAsSet =  new Set<DateTime>{
            DateTime.newInstance(currentDate, Time.newInstance(hour, 05, 00, 0)),
            DateTime.newInstance(currentDate, Time.newInstance(hour, 10, 00, 0)),
            DateTime.newInstance(currentDate, Time.newInstance(hour, 15, 00, 0)),
            DateTime.newInstance(currentDate, Time.newInstance(hour, 20, 00, 0)),
            DateTime.newInstance(currentDate, Time.newInstance(hour, 25, 00, 0)),
            DateTime.newInstance(currentDate, Time.newInstance(hour, 30, 00, 0)),
            DateTime.newInstance(currentDate, Time.newInstance(hour, 35, 00, 0)),
            DateTime.newInstance(currentDate, Time.newInstance(hour, 40, 00, 0))  
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
        HeartbeatImplementation.updateLastEventStamp( heartbeats );

        // assemble
        BrokerSetting__c settings = BrokerSetting__c.getInstance();
        DateTime actualEventStamp = HeartbeatImplementation.getISO8601AsDateTime(settings.EventStamp__c);
      
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
        HeartbeatImplementation.updateLastEventStamp( heartbeats );

        // assemble
        BrokerSetting__c settings = BrokerSetting__c.getInstance();
        DateTime actualEventStamp = HeartbeatImplementation.getISO8601AsDateTime(settings.EventStamp__c);
      
        // assert
        DateTime expectedEventStamp =  stampC;
        System.assertEquals(expectedEventStamp, actualEventStamp);
    }

 
    static testMethod void callingGenerateHeartbeatsInsertsExpectedMessages() {
        // arrange 
        Integer intervalInMinutes = 05;
        
        Date currentDate = Date.newInstance(2014,12,16);
        
        Integer  hour   = 03;
        Integer  second = 07;
        Integer  minute = 42;
        Time currentTime = Time.newInstance(hour, minute, second, 0);
        DateTime currentDateTime = DateTime.newInstance(currentDate, currentTime);
        
        Integer lastEventMinute = 00;
        Time lastEventTime = Time.newInstance(hour, lastEventMinute, 00, 0);
        DateTime lastEventStamp =  DateTime.newInstance(currentDate, lastEventTime);
        
        insert new BrokerSetting__c(BrokerClassName__c = SynchronousBroker.class.getName());
        
        // act
        HeartbeatImplementation.generateHeartbeats(intervalInMinutes, lastEventStamp, currentDateTime);
        
        
        // assemble
        List<Message__c> actualMessages = [SELECT  Id, Parameters__c FROM Message__c];
        Integer actualCount  = actualMessages.size();
        
        Set<String> expectedHeartbeatsAsSet =  new Set<String>{
                  HeartbeatImplementation.getISO8601(DateTime.newInstance(currentDate, Time.newInstance(hour, 05, 00, 0))),
               HeartbeatImplementation.getISO8601(DateTime.newInstance(currentDate, Time.newInstance(hour, 10, 00, 0))),
               HeartbeatImplementation.getISO8601(DateTime.newInstance(currentDate, Time.newInstance(hour, 15, 00, 0))),
               HeartbeatImplementation.getISO8601(DateTime.newInstance(currentDate, Time.newInstance(hour, 20, 00, 0))),
               HeartbeatImplementation.getISO8601(DateTime.newInstance(currentDate, Time.newInstance(hour, 25, 00, 0))),
               HeartbeatImplementation.getISO8601(DateTime.newInstance(currentDate, Time.newInstance(hour, 30, 00, 0))),
               HeartbeatImplementation.getISO8601(DateTime.newInstance(currentDate, Time.newInstance(hour, 35, 00, 0))),
               HeartbeatImplementation.getISO8601(DateTime.newInstance(currentDate, Time.newInstance(hour, 40, 00, 0)))  
         }; 
          
        Boolean actualFlag = true;
        for (Message__c actualMessage : actualMessages) {
            Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(actualMessage.Parameters__c);
            String actualEventStamp = (String)parameters.get('__EventStamp');
            if (!expectedHeartbeatsAsSet.contains(actualEventStamp))
                actualFlag = false;
        }

        // assert
        Integer expectedCount  = expectedHeartbeatsAsSet.size();
        System.assertEquals(expectedCount, actualCount);
        Boolean expectedFlag = true;
        System.assertEquals(expectedFlag, actualFlag);
    }

 
    static testMethod void callingGenerateHeartbeatsViaInterfaceInsertsExpectedMessages() {
        // arrange 
        Integer intervalInMinutes = 05;
        
        Date currentDate = Date.newInstance(2014,12,16);
        
        Integer  hour   = 03;
        Integer  second = 07;
        Integer  minute = 42;
        Time currentTime = Time.newInstance(hour, minute, second, 0);
        DateTime currentDateTime = DateTime.newInstance(currentDate, currentTime);
        
        Integer lastEventMinute = 00;
        Time lastEventTime = Time.newInstance(hour, lastEventMinute, 00, 0);
        DateTime lastEventStamp =  DateTime.newInstance(currentDate, lastEventTime);
        
        insert new BrokerSetting__c(BrokerClassName__c = SynchronousBroker.class.getName());
        
        // act
        HeartbeatImplementation.IHeartbeatGenerator heartbeatGeneratorMock = (HeartbeatImplementation.IHeartbeatGenerator) 
            new HeartbeatImplementation.HeartbeatGeneratorMock(
                intervalInMinutes, 
                lastEventStamp, 
                currentDateTime
            );

        heartbeatGeneratorMock.generateHeartbeats();
        
        
        // assemble
        List<Message__c> actualMessages = [SELECT  Id, Parameters__c FROM Message__c];
        Integer actualCount  = actualMessages.size();
        
        Set<String> expectedHeartbeatsAsSet =  new Set<String>{
                  HeartbeatImplementation.getISO8601(DateTime.newInstance(currentDate, Time.newInstance(hour, 05, 00, 0))),
               HeartbeatImplementation.getISO8601(DateTime.newInstance(currentDate, Time.newInstance(hour, 10, 00, 0))),
               HeartbeatImplementation.getISO8601(DateTime.newInstance(currentDate, Time.newInstance(hour, 15, 00, 0))),
               HeartbeatImplementation.getISO8601(DateTime.newInstance(currentDate, Time.newInstance(hour, 20, 00, 0))),
               HeartbeatImplementation.getISO8601(DateTime.newInstance(currentDate, Time.newInstance(hour, 25, 00, 0))),
               HeartbeatImplementation.getISO8601(DateTime.newInstance(currentDate, Time.newInstance(hour, 30, 00, 0))),
               HeartbeatImplementation.getISO8601(DateTime.newInstance(currentDate, Time.newInstance(hour, 35, 00, 0))),
               HeartbeatImplementation.getISO8601(DateTime.newInstance(currentDate, Time.newInstance(hour, 40, 00, 0)))  
         }; 
          
        Boolean actualFlag = true;
        for (Message__c actualMessage : actualMessages) {
            Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(actualMessage.Parameters__c);
            String actualEventStamp = (String)parameters.get('__EventStamp');
            if (!expectedHeartbeatsAsSet.contains(actualEventStamp))
                actualFlag = false;
        }

        // assert
        Integer expectedCount  = expectedHeartbeatsAsSet.size();
        System.assertEquals(expectedCount, actualCount);
        Boolean expectedFlag = true;
        System.assertEquals(expectedFlag, actualFlag);
    }  

}