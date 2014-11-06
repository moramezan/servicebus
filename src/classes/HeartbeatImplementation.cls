/**
 * DO NOT SCHEDULE THIS CLASS EVER
 * http://salesforce.stackexchange.com/a/24448/320
 */
public with sharing class HeartbeatImplementation implements System.Schedulable {
    
    @testVisible
    private static String SystemHeartbeatSequence = 'HeartbeatSequence';
 
    
    public void execute(System.SchedulableContext context) {
        HeartbeatImplementation.IHeartbeatGenerator heartbeatGenerator = 
            (HeartbeatImplementation.IHeartbeatGenerator) new HeartbeatImplementation.HeartbeatGeneratorImpl();
        heartbeatGenerator.generateHeartbeats();    
    }


    public interface IHeartbeatGenerator {
        void generateHeartbeats();
    }
    
 

    /*
     * Encapsulation of the Hearbeat message generation parameters and logic
     *
     */
    public class HeartbeatGeneratorImpl implements HeartbeatImplementation.IHeartbeatGenerator {
        public Integer  IntervalInMinutes  {get; private set;}
        public DateTime LastEventStamp     {get; private set;}
        public DateTime CurrentDateTime    {get; private set;}    
 
        public  HeartbeatGeneratorImpl() {
            //EventStamp: null is still valid (first run)
            String eventStampAsString = HeartbeatSettings__c.getInstance().EventStamp__c;
            DateTime  eventStampAsDateTime = 
                (eventStampAsString != null) ? 
                getISO8601AsDateTime(eventStampAsString) :
                null;

            // no suicide chaining : set to 60
            // suicide schedule : set as low as 5
            // suicide queuable : set as low as 1
            this.IntervalInMinutes = 60; 
            
            this.LastEventStamp = eventStampAsDateTime; 
            this.CurrentDateTime = system.now();   
         }
            
        public void generateHeartbeats() {
            HeartbeatImplementation.refreshConfiguration();
            HeartbeatImplementation.generateHeartbeats(intervalInMinutes, lastEventStamp, currentDateTime);
        }
    }   


    /*
     * Mock encapsulation of the Hearbeat message generation parameters and logic
     *
     */
    public class HeartbeatGeneratorMock implements HeartbeatImplementation.IHeartbeatGenerator {
        public Integer  IntervalInMinutes  {get; private set;}
        public DateTime LastEventStamp     {get; private set;}
        public DateTime CurrentDateTime    {get; private set;}    
    
        public  HeartbeatGeneratorMock(Integer intervalInMinutes, DateTime lastEventStamp, DateTime currentDateTime) {
            this.IntervalInMinutes = intervalInMinutes;
            this.LastEventStamp = lastEventStamp;
            this.CurrentDateTime = currentDateTime; 
        }
            
        public void generateHeartbeats() {
            HeartbeatImplementation.generateHeartbeats(intervalInMinutes, lastEventStamp, currentDateTime);
        }
    }   
    
    /*
     * Creates a list of time stamps based on the multiples of the interval in minutes 
     * WITH reference to the current time the last event stamp 
     */
    @testVisible
    private static List<DateTime> getHeartbeats(Integer intervalInMinutes, DateTime lastEventStamp, DateTime currentDateTime)
    {
        List<DateTime> heartbeats = new List<DateTime>();
     
        Boolean isGenesisHeartbeat =  (lastEventStamp == null);                   
        lastEventStamp = (isGenesisHeartbeat) ? getInitialStamp(intervalInMinutes, currentDateTime) : lastEventStamp;      
        if (isGenesisHeartbeat) {
            heartbeats.add(lastEventStamp);
        }
       
       
        DateTime suggestedEventStamp = lastEventStamp;
        while (true) {
            suggestedEventStamp = suggestedEventStamp.addMinutes(intervalInMinutes);
            if (suggestedEventStamp > currentDateTime) break;
            heartbeats.add(suggestedEventStamp);
        }
        
        return heartbeats;
    }

    /*
     * The initial time stamp is the earliest multiple of the interval minutes with 
     * reference to the current time
     */
    @testVisible
    private static DateTime getInitialStamp(Integer intervalInMinutes,  DateTime currentDateTime)
    {
        List<Integer> intervals = new List<Integer>();
        Integer i = 0;
        while (i < 60) {
            intervals.add(i);
            i = i + intervalInMinutes;
        }

        Integer minuteInterval = 0;
        Integer minuteCurrent = currentDateTime.Minute();
        for (Integer interval : intervals) {
            Boolean inRange = (interval <  minuteCurrent);
            if (interval <=  minuteCurrent) 
                minuteInterval = interval; 
            if (!inRange) break;   
        } 

        return DateTime.newInstance(
            currentDateTime.year(),
            currentDateTime.month(),
            currentDateTime.day(),
            currentDateTime.hour(),
            minuteInterval,
            0
        );
    }


    /* Updates the lst event stamp. The last event stamp is explicitly saved in ISO8601
     * format
     */
    @testVisible 
    private static void updateLastEventStamp( List<DateTime> heartbeats ) {
        Integer count = heartbeats.size();
        if (count == 0)
            return;
    
        DateTime lastEventStamp =  heartbeats[count-1];
        String lastEventStampAsString = getISO8601(lastEventStamp);
        HeartbeatSettings__c  setting = new HeartbeatSettings__c() ;  
        List<HeartbeatSettings__c> settings =  [SELECT Id, EventStamp__c FROM HeartbeatSettings__c];
        if (settings.size() != 0) {
            setting = settings[0];
        }
        setting.EventStamp__c = lastEventStampAsString;
        upsert setting;                                                                   
    }


    @testVisible
    private static void generateHeartbeats(Integer intervalInMinutes, DateTime lastEventStamp, DateTime currentDateTime) {
        List<DateTime> heartbeats =  getHeartbeats(intervalInMinutes, lastEventStamp, currentDateTime);
      
        updateLastEventStamp(heartbeats);

        for (DateTime heartbeat : heartbeats) {
            Map<String,Object> parameters = new Map<String,Object>{
                'Id' => UserInfo.getUserId(), 
                'eda_SequenceName' => SystemHeartbeatSequence,    
                'eda_EventStamp' => getISO8601(heartbeat),
                'eda_IsHeartbeat' => true    
            };
            Broker.enqueue(parameters);
        }
    }
 
    
    /* ISO 8601 Data elements and interchange formats – Information interchange – Representation of dates and times is an
     * international standard covering the exchange of date and time-related data.  [...]  a basic format with 
     * a minimal number of separators [...] 
     * The separator used between date values is the hyphen,  while the colon is used as the separator between time values
     *
     * Time zone designators 
     * Time zones in ISO 8601 are represented as local time (with the location unspecified), as UTC, or as an 
     * offset from UTC. If no UTC relation information is given with a time representation, the time is assumed to be 
     * in local time. While it may be safe to assume local time when communicating in the same time zone, it is ambiguous 
     * when used in communicating across different time zones. It is usually preferable to indicate a time zone 
     * (zone designator) using the standard's notation.
     * 
     * UTC 
     * If the time is in UTC, add a Z directly after the time without a space. 
     * Z is the zone designator for the zero UTC offset. "09:30 UTC" is therefore represented as "09:30Z"
     */
    @testVisible
    static private String getISO8601(DateTime stamp) {
        return ((''+stamp).replace(' ','T'))+'Z'; // or json.serialize(stamp) but that returns (unwanted) milliseconds)
    }

    @testVisible
    private static DateTime getISO8601AsDateTime(String stamp) {
        if (stamp == null) 
            return null;
        
        return (DateTime)Json.deserialize('"' + stamp + '"', DateTime.class);
    }


    // START OF FUCKERY 
    
    /*
     * Context (and the mind on N Reid) :
     *
     * Consider this simple thought experiment : classify (ie place somewhere) the following :
     *   Polar Bear, 
     *   Black Eagle, 
     *   Crow, 
     *   Black House Cat, 
     *   Dove, 
     *   Black Australian Swan,
     *   (White) Swan, 
     *   Panther
     *
     * In other words, classify the species - http://www.youtube.com/watch?v=IM1-DQ2Wo_w
     *
     * Three possibilities come to mind:
     *    #1 Cats:        [Black House Cat, Panther], 
     *       Bears:       [Polar Bear] 
     *       Birds:       [Black Eagle, Crow, Dove, Black Australian Swan,(White) Swan]
     *    or 
     *    #2 Hunters:     [Polar Bear, Black Eagle, Black House Cat, Panther] 
     *       Non-Hunters: [Crow, Dove, Black Australian Swan,(White) Swan]
     *    or 
     *    #3 Black:       [Black Eagle, Crow, Black House Cat, Black Australian Swan, Panther] 
     *       White:       [Polar Bear, Dove,(White) Swan]
     * 
     * The correct classification of course  depends on what you are optimizing for ...
     * and similarly, the code you write and where you place it depends on what you are optimizing for
     *     
     * So here is the point:
     *   I want this particular piece of fuckery code below to exist ... and I want it to be confined to 
     *   this particular class and leak no further 
     *   ... because it is nothing more than necessary "fuckery to compensate for other fuckery""
     *
     * What fuckery might that be?
     *   I believe we deviated from the Amtrix model when we initially made moves to adjust the order of firing 
     *   in the 4 stroke engine (I take my part of the "blame" in initiating that change - lol) 
     *   So ... by re-arranging the 4 stroke engine, ...
     *   the enqueue() method assumed some of the broker logic - specifically "RESOLVE" logic. 
     *   It was unfortunately unavoidable.
     *
     * Instinctively at the time , one "knew" this wasn't strictly correct but it solved the requirements ...
     * It short : enqueue() does more than it should .... 
     * It should just place a record in the message  table and start the broker, .., BUT ...
     * it also attempts to RESOLVE (broker functionality) in the same transaction context  ....
     * If enqueue cannot resolve , an error is correctly thrown and unfortunately the event (ie the message)
     * doesn't  make it onto the message table.
     * 
     * And that's the issue  - the event happened ** regardless of a successful resolution ** and should be captured
     * into the "event store" (ie captured into the messages table).  Specifically with respect to time events, 
     * by 5pm , 12:00 happened ,  13:00 happened, ... so did 14:00 etc , etc ... regardless of whether of not our 
     * engine had a resolution issue
     * Again the ** events happened and events that happened need to be captured **
     *
     * (Incidentally, the fuckery inherent in the  enqueue() method surfaces itself again when we 
     * attempt to present a graph of messages versus processes on the monitor page )
     * 
     * With the above theoretical foundation in mind, it's Neil's considered opinion that given the current 
     * fuckery in the enqueue() method (see comments above) we should do everything possible to make sure 
     * the "event store" matches reality as close as as possible -  that, ... in practical terms means ensuring the 
     * requisite Sequence, Steps and Processes are ALWAYS in place to deal with the resolution logic that is called 
     * by an enqueue() method that (for good reason) unfortunately does too much - we do everything 
     * we possibly can to avoid an exception being thrown and that's why we do the following code 
     * here ... it's "dirty compensating fuckery" code to deal with "pre-existing fuckery"
     *
     *
     */
     
    /*
     * Validation of Configuration
     */
     
    @testVisible
    private static Boolean isConfiguredHeartbeatProcess() {
        List<Process__c> processes = [ 
            SELECT Id, Name
            FROM Process__c 
            WHERE Name = :Heartbeat.class.getName() 
        ];
        
       return (processes.size() == 1); 
    }
    @testVisible
    private static Boolean isConfiguredTerminateProcess() {
        List<Process__c> processes = [ 
            SELECT Id, Name
            FROM Process__c 
            WHERE Name = :Terminate.class.getName() 
        ];
        
       return (processes.size() == 1); 
    }


    @testVisible
    private static Boolean isConfiguredProcess(Boolean isConfiguredTerminateProcess, Boolean isConfiguredHeartbeatProcess) {
        return (isConfiguredTerminateProcess && isConfiguredHeartbeatProcess); 
    }

    @testVisible
    private static Boolean isConfiguredSequence(Boolean isConfiguredProcess) {
        if (!isConfiguredProcess)
            return false;
            
        List<Sequence__c> sequences  = [SELECT Id, Name FROM Sequence__c WHERE Name = :SystemHeartbeatSequence];
        return (sequences.size() == 1); 
    }


    @testVisible
    private static Boolean isConfiguredStep(Boolean isConfiguredSequence) {
        
        if (!isConfiguredSequence)
            return false;
            
        List<Step__c> steps = [ 
            SELECT Id, Name
            FROM Step__c 
            WHERE Process__r.Name = :Heartbeat.class.getName() 
            AND Position__c = 1 
            AND Sequence__r.Name = :SystemHeartbeatSequence
        ];
        return (steps.size() == 1);
    }


    /*
     * Configuration  refresh 
     * (required logic run as and when  needed ...)
     */
    @testVisible
    private static void refreshConfiguration() {
        if (!SObjectType.Process__c.Createable) throw new Broker.CrudException('!SObjectType.Process__c.Createable');
        if (!SObjectType.Sequence__c.Createable) throw new Broker.CrudException('!SObjectType.Sequence__c.Createable');
        if (!SObjectType.Step__c.Createable) throw new Broker.CrudException('!SObjectType.Step__c.Createable');
        if (!SObjectType.Step__c.Deletable) throw new Broker.CrudException('!SObjectType.Step__c.Deletable');

        // verify:
        Boolean isConfiguredHeartbeatProcess = isConfiguredHeartbeatProcess();
        Boolean isConfiguredTerminateProcess = isConfiguredTerminateProcess();
        Boolean isConfiguredProcess = isConfiguredProcess(isConfiguredHeartbeatProcess, isConfiguredTerminateProcess);
        Boolean isConfiguredSequence = isConfiguredSequence(isConfiguredProcess);
        Boolean isConfiguredStep = isConfiguredStep(isConfiguredSequence);   
        
        // refresh as needed:
        Process__c heartbeatProcess;
        Process__c terminateProcess;
        Sequence__c sequence;
        
        if (!isConfiguredHeartbeatProcess) {
            try {
                heartbeatProcess = ProcessObject.fromType(Heartbeat.class);
                insert heartbeatProcess;    
            } catch (Exception e) {
                e.setMessage('Cannot configure '  + Heartbeat.class.getName() + ' process in process object - ' + e.getMessage());
                throw new Broker.CrudException(e);
            }
        } else {
            heartbeatProcess = [SELECT Id, Name FROM Process__c WHERE Name = :Heartbeat.class.getName()][0];
        }
        
        if (!isConfiguredTerminateProcess) {
            try {
                terminateProcess = ProcessObject.fromType(Terminate.class);
                insert terminateProcess;    
            } catch (Exception e) {
                e.setMessage('Cannot configure '  + Terminate.class.getName() + ' process in process object - ' + e.getMessage());
                throw new Broker.CrudException(e);
            }
        } else {
            terminateProcess = [SELECT Id, Name FROM Process__c WHERE Name = :Terminate.class.getName()][0];
        } 

        if (!isConfiguredSequence) {
            try {
                sequence = new Sequence__c(Name = SystemHeartbeatSequence);
                insert sequence; 
            } catch (Exception e) {
                e.setMessage('Cannot configure ' + SystemHeartbeatSequence + ' sequence - ' + e.getMessage());
                throw new Broker.CrudException(e);
            }
        } else {
            sequence  = [SELECT Id, Name FROM Sequence__c WHERE Name = :SystemHeartbeatSequence][0];
        }

        if (!isConfiguredStep) {
            try {
                List<Step__c> steps = new List<Step__c>{
                    new Step__c(Sequence__c = sequence.Id ,Position__c = 1,Process__c = heartbeatProcess.Id),
                    new Step__c(Sequence__c = sequence.Id ,Position__c = 2,Process__c = terminateProcess.Id)
                };
                delete [SELECT Id FROM Step__c WHERE Sequence__c = :sequence.Id]; 
                insert steps;
            } catch (Exception e) {
                e.setMessage('Cannot configure ' + Heartbeat.class.getName()  + ' and/or ' + Terminate.class.getName() +
                    ' step(s) on ' + SystemHeartbeatSequence + ' sequence - ' + e.getMessage()
                );
                throw new Broker.CrudException(e);
            }
        }    
    } 
    // END OF FUCKERY 
        
}