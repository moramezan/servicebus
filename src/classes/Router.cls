/**
 * @Obfuscation
 * Formerly known as Heartbeat
 */
public class Router extends ApexClassModel.Service {
    void callout(Map<String,Object> inputEvent) {}
    
    //#575 heartbeat evades discovery
    //public class Summary {}
    
    List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
        
        //#1124
        this.retryStartedMessages();
        
        //current versions only
        List<Step__c> schedules = [
            SELECT Id, Sequence__c, Position__c
            FROM Step__c
            WHERE ApexTypeName__c = :ScheduleService.class.getName()
            AND Version__c = :Application__c.getOrgDefaults().RouterVersion__c
        ];
        
        //stamp with version
        Integer version = Application__c.getOrgDefaults().RouterVersion__c.intValue();
        integer position = 0;
        
        List<Map<String,Object>> outputEvents = new List<Map<String,Object>>();
        for (Step__c schedule : schedules) outputEvents.add(new Map<String,Object>{
            'ToSequence' => schedule.Sequence__c,
            'ToService' => null, //null out accumulated parameter
            'RecordId' => inputEvent.get('RecordId') //#971 this carries difference between heartbeat and test message
        });
        
        //destined for any schedule steps
        return outputEvents;
    }
    
    /**
     * For #1124 we make one re-attempt within one hour. This
     * is in the interest of a very bare minimum viable retry.
     * If users want a more comprehensive retry, they might be
     * able to interrogate the message table by attempts etc.
     */
    @TestVisible void retryStartedMessages() {
        
        List<Message__c> messages = [
            SELECT Id
            FROM Message__c
            WHERE Status__c = 'Started'
            AND Exception__c != null
            AND IsAutoRetryable__c = true
            AND NumberOfAttempts__c = 1
            LIMIT 5000
        ];
        
        for (Message__c message : messages) {
            message.Status__c = 'Buffered';
            message.Exception__c = null;
        }
        
        update messages;
        
    }
    
    static Id RecordId;
    
    /**
     * We must do this inside a Future method otherwise we get error:
     * Scheduler: failed to execute scheduled job: jobId: 707j0000004w8PC,
     * class: common.apex.async.AsyncApexJobModel,
     * reason: Callout from scheduled Apex not supported.
     */

    public interface IHeartbeatGenerator {
        void generateHeartbeats();
    }
    
    /*
     * Encapsulation of the Hearbeat message generation parameters and logic
     *
     */
    public class HeartbeatGeneratorImpl implements IHeartbeatGenerator {
        public Integer  IntervalInMinutes  {get; private set;}
        public DateTime LastEventStamp     {get; private set;}
        public DateTime CurrentDateTime    {get; private set;}
 
        public  HeartbeatGeneratorImpl() {
            Datetime eventStampAsDateTime = Application__c.getOrgDefaults().BrokerLastTimestamp__c;
            
            // no suicide chaining : set to 60
            // suicide schedule : set as low as 5
            // suicide queuable : set as low as 1
            this.IntervalInMinutes = 60;
            
            this.LastEventStamp = eventStampAsDateTime;
            this.CurrentDateTime = System.now(); // Don't believe we need to GMT this
         }
            
        public void generateHeartbeats() {
            generateHeartbeats(intervalInMinutes, lastEventStamp, currentDateTime);
        }
    }


    /*
     * Mock encapsulation of the Hearbeat message generation parameters and logic
     *
     */
    public class HeartbeatGeneratorMock implements IHeartbeatGenerator {
        public Integer  IntervalInMinutes  {get; private set;}
        public DateTime LastEventStamp     {get; private set;}
        public DateTime CurrentDateTime    {get; private set;}
    
        public  HeartbeatGeneratorMock(Integer intervalInMinutes, DateTime lastEventStamp, DateTime currentDateTime) {
            this.IntervalInMinutes = intervalInMinutes;
            this.LastEventStamp = lastEventStamp;
            this.CurrentDateTime = currentDateTime;
        }
            
        public void generateHeartbeats() {
            generateHeartbeats(intervalInMinutes, lastEventStamp, currentDateTime);
        }
    }
    
    /*
     * Creates a list of time stamps based on the multiples of the interval in minutes
     * WITH reference to the current time the last event stamp
     */
    @TestVisible static List<DateTime> getHeartbeats(Integer intervalInMinutes, DateTime lastEventStamp, DateTime currentDateTime)
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
    @TestVisible static DateTime getInitialStamp(Integer intervalInMinutes,  DateTime currentDateTime)
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
    @TestVisible static void updateLastEventStamp( List<DateTime> heartbeats ) {
        Integer count = heartbeats.size();
        if (count == 0)
            return;
    
        DateTime lastEventStamp =  heartbeats[count-1];
 
        Application__c application = Application__c.getOrgDefaults(); //#782
        application.BrokerLastTimestamp__c = lastEventStamp;
      //////  setting.EventStampInfo__c = json.serialize(lastEventStamp).replaceAll('"','').left(19)+'Z';  // Info purposes only
        upsert application;
    }


    @TestVisible static void generateHeartbeats(Integer intervalInMinutes, DateTime lastEventStamp, DateTime currentDateTime) {
        List<DateTime> timestamps =  getHeartbeats(intervalInMinutes, lastEventStamp, currentDateTime);
        
        updateLastEventStamp(timestamps);
        
        List<Map<String,Object>> inputEvents = new List<Map<String,Object>>();
        for (DateTime timestamp : timestamps) inputEvents.add(new Map<String,Object>{
            'RecordId' => RecordId, //#971 used in lieu of :WasHeartbeat
            'EntryPointTimestamp' => timestamp,
            'ToService' => Router.class.getName() //#956 and #575 so that resolve and execute can crow look //#999#issuecomment-133751700
        });
        
        if (inputEvents.isEmpty()) {
            //nothing to do
            return;
        }
        
        //heartbeats are processed immediately
        List<Map<String,Object>> outputEvents = new List<Map<String,Object>>();
        for (Map<String,Object> inputEvent : inputEvents) outputEvents.addAll(new Router().handle(inputEvent));

        if (outputEvents.isEmpty()) {
            //nothing to do
            return;
        }
        
        //#952 wake up broker
        Enqueue.invoke(outputEvents);
    }
    
    public class ScheduleImpl implements RouterSchedule.Schedulable {
    
        public void execute(System.SchedulableContext context) {
            //#971 used in lieu of :WasHeartbeat
            RecordId = context.getTriggerId(); //eg 08e24000007paG1AAI
            IHeartbeatGenerator heartbeatGenerator = new HeartbeatGeneratorImpl();
            heartbeatGenerator.generateHeartbeats();
        }
        
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
     * attempt to present a graph of messages versus services on the monitor page )
     *
     * With the above theoretical foundation in mind, it's Neil's considered opinion that given the current
     * fuckery in the enqueue() method (see comments above) we should do everything possible to make sure
     * the "event store" matches reality as close as as possible -  that, ... in practical terms means ensuring the
     * requisite Sequence, Steps and Services are ALWAYS in place to deal with the resolution logic that is called
     * by an enqueue() method that (for good reason) unfortunately does too much - we do everything
     * we possibly can to avoid an exception being thrown and that's why we do the following code
     * here ... it's "dirty compensating fuckery" code to deal with "pre-existing fuckery"
     *
     *
     */
}