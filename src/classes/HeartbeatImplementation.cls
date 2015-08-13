/**
 * DO NOT SCHEDULE THIS CLASS EVER
 * http://salesforce.stackexchange.com/a/24448/320
 */
public class HeartbeatImplementation implements System.Schedulable {
    
    public void execute(System.SchedulableContext context) {
        if (!Test.isRunningTest() && OAuthSetting__c.getOrgDefaults().RefreshToken__c != null) {
            //#728 keep access token roaring and ready every hour IF configured ok
            defer();
        }
        
        HeartbeatImplementation.IHeartbeatGenerator heartbeatGenerator =
            (HeartbeatImplementation.IHeartbeatGenerator) new HeartbeatImplementation.HeartbeatGeneratorImpl();
        heartbeatGenerator.generateHeartbeats();
    }
    
    /**
     * We must do this inside a Future method otherwise we get error:
     * Scheduler: failed to execute scheduled job: jobId: 707j0000004w8PC,
     * class: common.apex.async.AsyncApexJobModel,
     * reason: Callout from scheduled Apex not supported.
     */
    @Future(callout=true) static public void defer() {
        ConfigureController.refreshAccessToken();
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
            DateTime  eventStampAsDateTime = BrokerSetting__c.getOrgDefaults().EventStamp__c;
            
            // no suicide chaining : set to 60
            // suicide schedule : set as low as 5
            // suicide queuable : set as low as 1
            this.IntervalInMinutes = 60;
            
            this.LastEventStamp = eventStampAsDateTime;
            this.CurrentDateTime = System.now(); // Don't believe we need to GMT this
         }
            
        public void generateHeartbeats() {
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
 
        BrokerSetting__c setting = BrokerSetting__c.getOrgDefaults(); //#782
        setting.EventStamp__c = lastEventStamp;
      //////  setting.EventStampInfo__c = json.serialize(lastEventStamp).replaceAll('"','').left(19)+'Z';  // Info purposes only
        upsert setting;
    }


    @testVisible
    private static void generateHeartbeats(Integer intervalInMinutes, DateTime lastEventStamp, DateTime currentDateTime) {
        List<DateTime> heartbeats =  getHeartbeats(intervalInMinutes, lastEventStamp, currentDateTime);
      
        updateLastEventStamp(heartbeats);

        List<Map<String,Object>> outputEvents = new List<Map<String,Object>>();
        for (DateTime heartbeat : heartbeats) {
            Map<String,Object> outputEvent = new Map<String,Object>{
                'esb__RecordId' => UserInfo.getUserId(),
                '__SequenceName' => '__Heartbeat', //avoid "Mandatory parameter esb__SequenceName not supplied."
                '__Position' => 0, //avoid "Mandatory parameter esb__SequenceName not supplied."
                'esb__EntryPointDatetime' => heartbeat,
                '__IsHeartbeatProcess' => true //#575 so that resolve and execute can crow look
            };
            outputEvents.add(outputEvent);
        }
        
        //Workaround for known issue: "Method only allowed during testing"
        //https://success.salesforce.com/issues_view?id=a1p300000008XM1AAM
        if (Test.isRunningTest()) new Job(outputEvents).execute(null);
        else System.enqueueJob(new Job(outputEvents));
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
     
}