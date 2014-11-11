public with sharing class Schedule {
    
    public class ScheduleException  extends Exception {}
    
    public class Meta {
        public String Tag = 'Event Driven Architecture';
        public String Name = 'Schedule';
        public String Description = 'Releases a scheduled heartbeat message'; //Swallows regular un-scheduled heartbeat messages
        public String Icon = 'clock';
        public SObject ConfigObject = ScheduleConfiguration__c.SObjectType.newSObject();
        public String DocsPageUrl = Url.getSalesforceBaseUrl().toExternalForm() + Page.ScheduleHelp.getUrl();
        public Boolean ConsumesHeartbeat = true;
    }
    
    public String Parameters;
    
    override public String toString() {
        Map<String,Object> parameters = (Map<String,Object>)Json.deserializeUntyped(this.Parameters);

        Boolean isHeartbeat = (Boolean)parameters.get('eda_IsHeartbeat');
        String  stampAsString  =  (String)parameters.get('eda_EventStamp');
        Id configurationId = (Id)parameters.get('eda_ConfigObjectId');

         List<Map<String,Object>> parametersList = new List<Map<String,Object>>();
    
        if (isHeartbeat) {
            // evaluate:
            if (isWithinWindow(stampAsString, configurationId)) {
                parametersList.add(parameters);
            } 
        } else { 
            // passthru:
            parametersList.add(parameters);
        }
    
        return Json.serialize(parametersList);
    }

    @TestVisible static private Boolean isWithinWindow(String stampAsString, Id configurationId) {
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
            ScheduleConfiguration__c configuration = (ScheduleConfiguration__c)SalesforceObject.getById(configurationId);
            frequency = configuration.Frequency__c;
            details = new Set<String>(configuration.FriendlyDates__c.split(';'));
            runTimes = new Set<String>(configuration.FriendlyTimes__c.split(';'));
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