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
        HeartbeatSettings__c settings = HeartbeatSettings__c.getInstance();
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
        HeartbeatSettings__c settings = HeartbeatSettings__c.getInstance();
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
        
        Process__c heartbeatProcess = ProcessObject.generateOne(Heartbeat.class);

        String sequenceName = HeartbeatImplementation.SystemHeartbeatSequence;
        Sequence__c sequence = new Sequence__c(Name = sequenceName);
        insert sequence;
        
        Step__c step  = new Step__c(Sequence__c = sequence.Id ,Position__c = 1,Process__c = heartbeatProcess.Id);
        insert step;
  
        insert new BrokerSettings__c(BrokerClassName__c = SynchronousBroker.class.getName());
        
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
            String actualEventStamp = (String)parameters.get('eda_EventStamp');
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
        
        Process__c heartbeatProcess = ProcessObject.generateOne(Heartbeat.class);

        String sequenceName = HeartbeatImplementation.SystemHeartbeatSequence;
        Sequence__c sequence = new Sequence__c(Name = sequenceName);
        insert sequence;
        
        Step__c step  = new Step__c(Sequence__c = sequence.Id ,Position__c = 1,Process__c = heartbeatProcess.Id);
        insert step;
  
        insert new BrokerSettings__c(BrokerClassName__c = SynchronousBroker.class.getName());
        
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
            String actualEventStamp = (String)parameters.get('eda_EventStamp');
            if (!expectedHeartbeatsAsSet.contains(actualEventStamp))
                actualFlag = false;
        }

        // assert
        Integer expectedCount  = expectedHeartbeatsAsSet.size();
        System.assertEquals(expectedCount, actualCount);
        Boolean expectedFlag = true;
        System.assertEquals(expectedFlag, actualFlag);
    }  

 
    static testMethod void callingIsConfiguredProcessReturnsFalseIfNotConfigured() {
        // arrange 
        Boolean actualConfiguredHeartbeatProcess  =  HeartbeatImplementation.isConfiguredHeartbeatProcess();
        Boolean actualConfiguredTerminateProcess  =  HeartbeatImplementation.isConfiguredTerminateProcess();
        
        // act 
        Boolean actualConfiguredProcess  =  HeartbeatImplementation.isConfiguredProcess(
            actualConfiguredHeartbeatProcess, 
            actualConfiguredTerminateProcess
        );  
        
        // assert
        Boolean expectedConfiguredProcess  = false;
        System.assertEquals( expectedConfiguredProcess ,actualConfiguredProcess );
    }

 
    static testMethod void callingIsConfiguredProcessReturnsTrueIfCorrectlyConfigured() {
        // arrange 
        Process__c heartbeatProcess = ProcessObject.generateOne(Heartbeat.class);
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        
        // act 
        Boolean actualConfiguredProcess  =  HeartbeatImplementation.isConfiguredProcess(
            HeartbeatImplementation.isConfiguredHeartbeatProcess(), 
            HeartbeatImplementation.isConfiguredTerminateProcess()
        );  

        // assert
        Boolean expectedConfiguredProcess   = true;
        System.assertEquals( expectedConfiguredProcess ,actualConfiguredProcess );
    }

 
    static testMethod void callingIsConfiguredSequenceReturnsFalseIfNotConfigured01() {
        // arrange 
        Boolean isConfiguredProcess = HeartbeatImplementation.isConfiguredProcess(false, false); 
        
        // act 
        Boolean actualConfiguredSequence = HeartbeatImplementation.isConfiguredSequence(isConfiguredProcess); 
        
        // assert
        Boolean expectedConfiguredSequence  = false;
        System.assertEquals( expectedConfiguredSequence , expectedConfiguredSequence);
    }

 
    static testMethod void callingIsConfiguredSequenceReturnsFalseIfNotConfigured02() {
        // arrange 
        Process__c heartbeatProcess = ProcessObject.generateOne(Heartbeat.class);
   
        Boolean isConfiguredProcess  =  HeartbeatImplementation.isConfiguredProcess(
            HeartbeatImplementation.isConfiguredHeartbeatProcess(), 
            HeartbeatImplementation.isConfiguredTerminateProcess()
        ); 
        
        // act 
        Boolean actualConfiguredSequence =  HeartbeatImplementation.isConfiguredSequence(isConfiguredProcess); 
        
        // assert
        Boolean expectedConfiguredSequence  = false;
        System.assertEquals( expectedConfiguredSequence , expectedConfiguredSequence);
    }

    
    static testMethod void callingIsConfiguredSequenceReturnsTrueIfCorrectlyConfigured() {
        // arrange 
        Process__c heartbeatProcess = ProcessObject.generateOne(Heartbeat.class);
        Process__c heartbeatTerminate = ProcessObject.generateOne(Terminate.class);
        String sequenceName = HeartbeatImplementation.SystemHeartbeatSequence;
        Sequence__c sequence = new Sequence__c(Name = sequenceName);
        insert sequence; 

        Boolean isConfiguredProcess  =  HeartbeatImplementation.isConfiguredProcess(
            HeartbeatImplementation.isConfiguredHeartbeatProcess(), 
            HeartbeatImplementation.isConfiguredTerminateProcess()
        ); 
        
 
        // act 
        Boolean actualConfiguredSequence =  HeartbeatImplementation.isConfiguredSequence(isConfiguredProcess); 
        
        // assert
        Boolean expectedConfiguredSequence = true;
        System.assertEquals( expectedConfiguredSequence , actualConfiguredSequence);
    }

 
    static testMethod void callingIsConfiguredStepReturnsFalseIfNotConfigured01() {
        // arrange 
        Process__c heartbeatProcess = ProcessObject.generateOne(Heartbeat.class);
        
        Boolean isConfiguredProcess  =  HeartbeatImplementation.isConfiguredProcess(
            HeartbeatImplementation.isConfiguredHeartbeatProcess(), 
            HeartbeatImplementation.isConfiguredTerminateProcess()
        ); 
        
        Boolean isConfiguredSequence = 
            HeartbeatImplementation.isConfiguredSequence(isConfiguredProcess);
        
        // act 
        Boolean actualConfiguredStep  = 
            HeartbeatImplementation.isConfiguredStep(isConfiguredSequence);  
        
        // assert
        Boolean expectedConfiguredStep  = false;   
        System.assertEquals( expectedConfiguredStep , actualConfiguredStep);
    }

 
    static testMethod void callingIsConfiguredStepReturnsFalseIfNotConfigured02() {
        // arrange 
        Process__c heartbeatProcess = ProcessObject.generateOne(Heartbeat.class);
        String sequenceName = HeartbeatImplementation.SystemHeartbeatSequence;
        Sequence__c sequence = new Sequence__c(Name = sequenceName);
        insert sequence;

        Boolean isConfiguredProcess  =  HeartbeatImplementation.isConfiguredProcess(
            HeartbeatImplementation.isConfiguredHeartbeatProcess(), 
            HeartbeatImplementation.isConfiguredTerminateProcess()
        ); 
        
        Boolean isConfiguredSequence = 
            HeartbeatImplementation.isConfiguredSequence(isConfiguredProcess);
        
        // act 
        Boolean actualConfiguredStep = HeartbeatImplementation.isConfiguredStep(isConfiguredSequence);  
        
        // assert
        Boolean expectedConfiguredStep  = false;   
        System.assertEquals( expectedConfiguredStep , actualConfiguredStep);
    }

 
    static testMethod void callingIsConfiguredStepReturnsTrueIfCorrectlyConfigured() {
        // arrange 
        Process__c heartbeatProcess = ProcessObject.generateOne(Heartbeat.class);
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        String sequenceName = HeartbeatImplementation.SystemHeartbeatSequence;
        Sequence__c sequence = new Sequence__c(Name = sequenceName);
        insert sequence;
        Step__c step1  = new Step__c(Sequence__c = sequence.Id ,Position__c = 1,Process__c = heartbeatProcess.Id);
        Step__c step2  = new Step__c(Sequence__c = sequence.Id ,Position__c = 2,Process__c = terminateProcess.Id);
        insert step1; 
        insert step2;
        
        Boolean isConfiguredProcess  =  HeartbeatImplementation.isConfiguredProcess(
            HeartbeatImplementation.isConfiguredHeartbeatProcess(), 
            HeartbeatImplementation.isConfiguredTerminateProcess()
        ); 
        
        Boolean isConfiguredSequence = 
            HeartbeatImplementation.isConfiguredSequence(isConfiguredProcess);
        
        // act 
        Boolean actualConfiguredStep = HeartbeatImplementation.isConfiguredStep(isConfiguredSequence);  
        
        // assert
        Boolean expectedConfiguredStep  = true;
        System.assertEquals( expectedConfiguredStep ,actualConfiguredStep );
    }   

 
    static testMethod void callingRefreshConfigCorrectlyConfiguresHeartbeatSequence() {
        // arrange 
        List<Process__c> processesBefore = [ 
            SELECT Id, Name
            FROM Process__c 
            WHERE Name = :Heartbeat.class.getName() 
        ];
        Integer actualProcessesBeforeCount = processesBefore.size();
        
        List<Sequence__c> sequencesBefore  = [
            SELECT Id, Name 
            FROM Sequence__c 
            WHERE Name = :HeartbeatImplementation.SystemHeartbeatSequence
        ];
        Integer actualSequencesBeforeCount = sequencesBefore.size();
        
        List<Step__c> stepsBefore = [ 
            SELECT Id, Name
            FROM Step__c 
            WHERE Process__r.Name = :Heartbeat.class.getName() 
            AND Position__c = 1 
            AND Sequence__r.Name = :HeartbeatImplementation.SystemHeartbeatSequence
        ];
        Integer actualStepsBeforeCount = stepsBefore.size();
        
        // act 
        HeartbeatImplementation.refreshConfig(); 
        
        // assemble
        List<Process__c> processesAfter = [ 
            SELECT Id, Name
            FROM Process__c 
            WHERE Name = :Heartbeat.class.getName() 
        ];
        Integer actualProcessesAfterCount = processesAfter.size();
        
        List<Sequence__c> sequencesAfter  = [
            SELECT Id, Name 
            FROM Sequence__c 
            WHERE Name = :HeartbeatImplementation.SystemHeartbeatSequence
        ];
        Integer actualSequencesAfterCount = sequencesAfter.size();
        
        List<Step__c> stepsAfter = [ 
            SELECT Id, Name
            FROM Step__c 
            WHERE Process__r.Name = :Heartbeat.class.getName() 
            AND Position__c = 1 
            AND Sequence__r.Name = :HeartbeatImplementation.SystemHeartbeatSequence
        ];
        Integer actualStepsAfterCount = stepsAfter.size();

        // assert 
        Integer expectedProcessesBeforeCount = 0;
        System.assertEquals( expectedProcessesBeforeCount , actualProcessesBeforeCount );
        Integer expectedSequencesBeforeCount = 0;
        System.assertEquals( expectedSequencesBeforeCount , actualSequencesBeforeCount );
        Integer expectedStepsBeforeCount = 0;
        System.assertEquals( expectedStepsBeforeCount ,     actualStepsBeforeCount );
        Integer expectedProcessesAfterCount = 1;
        System.assertEquals( expectedProcessesAfterCount ,  actualProcessesAfterCount );
        Integer expectedSequencesAfterCount = 1;
        System.assertEquals( expectedSequencesAfterCount , actualSequencesAfterCount );
        Integer expectedStepsAfterCount = 1;
        System.assertEquals( expectedStepsAfterCount ,   actualStepsAfterCount );
   }     
}