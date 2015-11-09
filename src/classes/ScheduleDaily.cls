public class ScheduleDaily extends ApexClassModel.Service {
    void callout(Map<String,Object> inputEvent) {}
    
    public class Summary {
        String Tag = 'Service Bus';
        String Label = 'Schedule (Daily)';
        String Description = 'Emits an event on a configurable hourly basis.'; //Swallows regular un-scheduled heartbeat messages
        String Icon = 'clock';
        String StepConfig = ScheduleDailyConfig__c.class.getName();
        //String HelpUrl = Page.ScheduleConfigHelp.getUrl();
        Boolean ConsumesHeartbeat = true;
        Integer Limits = 100; //could be higher but lets be reasonable
        Map<String,String> Inputs = new Map<String,String>{
            'EntryPointTimestamp' => 'DATETIME of the point in time this schedule was intended to run.'
        };
        public String Cardinality = 'One';
    }
    
    public class ScheduleException  extends Exception {}
    
    List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
        
        String recordId = (String)inputEvent.get('RecordId');
        //if (recordId == null) throw new ScheduleException('Null record id.'); //TODO (schedule does not necessarily contain heartbeat)
        
        Id stepConfigId = (String)inputEvent.get('StepConfigId');
        if (stepConfigId == null) throw new ScheduleException('Null step config id.');
        
        String stampAsString = (String)inputEvent.get('EntryPointTimestamp');
        if (stampAsString == null) throw new ScheduleException('Null entry point timestamp.');
        
        Boolean wasHeartbeat = false;
        if (recordId != null) wasHeartbeat = recordId.startsWith('08e'); //#810

        List<Map<String,Object>> outputEvents = new List<Map<String,Object>>();
    
        if (wasHeartbeat == true) {
            
            ScheduleDailyConfig__c config = (ScheduleDailyConfig__c)ApexDomain.getById(stepConfigId); //TODO
            /*ScheduleDailyConfig__c config = [
                SELECT IsActive__c, Frequency__c, FriendlyDates__c, FriendlyTimes__c
                FROM ScheduleDailyConfig__c
                WHERE Id = :stepConfigId
            ];*/
            
            if (config.IsActive__c != true) {
                //just swallow if not active
                return new List<Map<String,Object>>();
            }
            
            // evaluate:
            if (isWithinWindow(stampAsString, config)) {
                outputEvents.add(inputEvent);
            }
        } else {
            // passthru:
            outputEvents.add(inputEvent);
        }
    
        return outputEvents;
    }

    @TestVisible static Boolean isWithinWindow(String stampAsString, ScheduleDailyConfig__c config) {
        DateTime stampAsDateTime;
        try {
           stampAsString =  getISO8601(stampAsString);
           stampAsDateTime = getStamp(stampAsString);
        } catch (Exception e)  {
            throw new ScheduleException('Problem with getISO8601 or getStamp("' + stampAsString + '")', e);
        }

        String frequency;
        Set<String> details;
        Set<String> runTimes;
        try {
            frequency = 'Daily'; //TODO
            //frequency = config.Frequency__c;
            
            details = new Set<String>(); //TODO
            //details = new Set<String>(config.FriendlyDates__c.split(';'));
            
            runTimes = new Set<String>(); //TODO
            if (config.T0000__c) runTimes.add('00:00');
            if (config.T0100__c) runTimes.add('01:00');
            if (config.T0200__c) runTimes.add('02:00');
            if (config.T0300__c) runTimes.add('03:00');
            if (config.T0400__c) runTimes.add('04:00');
            if (config.T0500__c) runTimes.add('05:00');
            if (config.T0600__c) runTimes.add('06:00');
            if (config.T0700__c) runTimes.add('07:00');
            if (config.T0800__c) runTimes.add('08:00');
            if (config.T0900__c) runTimes.add('09:00');
            if (config.T1000__c) runTimes.add('10:00');
            if (config.T1100__c) runTimes.add('11:00');
            if (config.T1200__c) runTimes.add('12:00');
            if (config.T1300__c) runTimes.add('13:00');
            if (config.T1400__c) runTimes.add('14:00');
            if (config.T1500__c) runTimes.add('15:00');
            if (config.T1600__c) runTimes.add('16:00');
            if (config.T1700__c) runTimes.add('17:00');
            if (config.T1800__c) runTimes.add('18:00');
            if (config.T1900__c) runTimes.add('19:00');
            if (config.T2000__c) runTimes.add('20:00');
            if (config.T2100__c) runTimes.add('21:00');
            if (config.T2200__c) runTimes.add('22:00');
            if (config.T2300__c) runTimes.add('23:00');
            //runTimes = new Set<String>(config.FriendlyTimes__c.split(';'));
        } catch (Exception e) {
            throw new ScheduleException('Problem extracting times (' + config + ')');
            //throw new ScheduleException('Problem extracting frequency (' + config.Frequency__c + ') / dates (' + config.FriendlyDates__c + ') / times (' + config.FriendlyTimes__c + ')', e);
        }
        
        return isTimeMatch(stampAsString, runTimes);
        
        /*if (!isTimeMatch(stampAsString, runTimes)) {
            return false;
        } else {
            if (frequency == 'Daily') {
               if (isWithinDailyWindow(stampAsDateTime, details)) {
                    return true;
                }
            } else if (frequency == 'Weekly') {
                if (isWithinWeeklyWindow(stampAsDateTime, details)) {
                    return true;
                }
            } else if (frequency == 'Monthly') {
                if (isWithinMonthlyWindow(stampAsString, details)) {
                    return true;
                }
            }
        }*/
    }
    
    @TestVisible static Boolean isWithinWeeklyWindow(DateTime stampAsDateTime, Set<String> details) {
        String day = stampAsDateTime.format('EEEE');
        return details.contains(day);
    }
    
    @TestVisible static Boolean isWithinDailyWindow(DateTime stampAsDateTime, Set<String> details) {
        String day = stampAsDateTime.format('EEEE');
        
        Set<String> days = new Set<String>();
        
        if (details.contains('Working days only')) {
            days.addAll(new Set<String>{
                'Monday',
                'Tuesday',
                'Wednesday',
                'Thursday',
                'Friday'
            });
        }
        
        if (details.contains('Weekends and holidays')) {
            days.addAll(new Set<String>{
                'Saturday',
                'Sunday'
            });
        }
        
        return days.contains(day);
    }
 
    @TestVisible static Boolean isTimeMatch(String stampAsString, Set<String> runTimes) {
        Pattern myPattern = pattern.compile('.*T(\\d{2}:\\d{2}):\\d{2}.*');  // '2014-01-18T12:00:00.000Z'
        Matcher myMatcher = myPattern.matcher(stampAsString);
        if ( myMatcher.matches() && (myMatcher.groupCount() == 1)) {
            return runTimes.contains(myMatcher.group(1));
        }
        
        return false;
    }
    
    @TestVisible static Boolean isWithinMonthlyWindow(String stampAsString, Set<String> details) {
        Pattern myPattern = pattern.compile('\\d{4}-\\d{2}-(\\d{2})T\\d{2}:\\d{2}:\\d{2}.*');  // '2014-01-18T12:00:00.000Z'
        Matcher myMatcher = myPattern.matcher(stampAsString);
        if ( myMatcher.matches() && (myMatcher.groupCount() == 1)) {
            return details.contains(myMatcher.group(1));
        }
        
        return false;
    }
    
    static DateTime getStamp(String value) {
        return (DateTime)Json.deserialize('"' + getISO8601(value) + '"', DateTime.class);
    }
    
    static String getISO8601(String value) {
        value  = (value.endsWith('Z')) ? value :  value+'Z';
        DateTime localDateTime = (DateTime)Json.deserialize('"' + value + '"', DateTime.class);
        return ((''+localDateTime).replace(' ','T')); // or json.serialize(stamp) but that returns (unwanted) milliseconds)
    }
    
}