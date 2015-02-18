public with sharing class Schedule {
    
    public String Event;
    public ScheduleConfig__c StepConfig;
    
    public class ESB {
        public String Tag = 'Enterprise Service Bus';
        public String Name = 'Schedule';
        public String Description = 'Releases a scheduled heartbeat message'; //Swallows regular un-scheduled heartbeat messages
        public String Icon = 'clock';
        public SObject StepConfig = ScheduleConfig__c.SObjectType.newSObject();
        public String HelpUrl = Page.ScheduleConfigCsh.getUrl();
        public Boolean ConsumesHeartbeat = true;
        public Integer Limits = 5000; //leave half of 10,000 (Total number of records retrieved by Database.getQueryLocator)
        public Map<String,String> Inputs = new Map<String,String>{
            'esb__EntryPointDatetime' => 'DATETIME of the point in time this schedule was intended to run.'
        };
    }
    
    public class ScheduleException  extends Exception {}
    
    override public String toString() {
        Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(this.Event);

        String stampAsString = (String)parameters.get('esb__EntryPointDatetime');

        List<Map<String,Object>> parametersList = new List<Map<String,Object>>();
    
        if (stampAsString != null) {
            // evaluate:
            if (isWithinWindow(stampAsString, this.StepConfig)) {
                parametersList.add(parameters);
            } 
        } else { 
            // passthru:
            parametersList.add(parameters);
        }
    
        return Json.serialize(parametersList);
    }

    @TestVisible static private Boolean isWithinWindow(String stampAsString, ScheduleConfig__c config) {
        DateTime stampAsDateTime;
        try {
           stampAsString =  getISO8601(stampAsString);
           stampAsDateTime = getStamp(stampAsString);
        } catch (Exception e)  {
            throw new ScheduleException(e.getMessage());
        }

        String frequency;
        Set<String> details;
        Set<String> runTimes;
        try {
            frequency = config.Frequency__c;
            details = new Set<String>(config.FriendlyDates__c.split(';'));
            runTimes = new Set<String>(config.FriendlyTimes__c.split(';'));
        } catch (Exception e) {
            throw new ScheduleException(e);
        }

        if (!isTimeMatch(stampAsString, runTimes)) {
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
        }

        return false;
    }
    
    @TestVisible static private Boolean isWithinWeeklyWindow(DateTime stampAsDateTime, Set<String> details) {
        String day = stampAsDateTime.format('EEEE');
        return details.contains(day);
    } 
    
    @TestVisible static private Boolean isWithinDailyWindow(DateTime stampAsDateTime, Set<String> details) {
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
 
    @TestVisible static private Boolean isTimeMatch(String stampAsString, Set<String> runTimes) {
        Pattern myPattern = pattern.compile('.*T(\\d{2}:\\d{2}):\\d{2}.*');  // '2014-01-18T12:00:00.000Z'
        Matcher myMatcher = myPattern.matcher(stampAsString);
        if ( myMatcher.matches() && (myMatcher.groupCount() == 1)) {
            return runTimes.contains(myMatcher.group(1));
        }
        
        return false;
    }
    
    @TestVisible static private Boolean isWithinMonthlyWindow(String stampAsString, Set<String> details) {
        Pattern myPattern = pattern.compile('\\d{4}-\\d{2}-(\\d{2})T\\d{2}:\\d{2}:\\d{2}.*');  // '2014-01-18T12:00:00.000Z'
        Matcher myMatcher = myPattern.matcher(stampAsString);
        if ( myMatcher.matches() && (myMatcher.groupCount() == 1)) {
            return details.contains(myMatcher.group(1));
        }
        
        return false;
    }
    
    static private DateTime getStamp(String value) {
        return (DateTime)Json.deserialize('"' + getISO8601(value) + '"', DateTime.class);  
    }
    
    static private String getISO8601(String value) {
        value  = (value.endsWith('Z')) ? value :  value+'Z';
        DateTime localDateTime = (DateTime)Json.deserialize('"' + value + '"', DateTime.class);
        return ((''+localDateTime).replace(' ','T')); // or json.serialize(stamp) but that returns (unwanted) milliseconds)
    }
    
}