public class ScheduleService extends ApexClassModel.Service {
    
    public class Definition extends ApexClassModel.Definition {
        String Tag = 'Services';
        String Label = 'Schedule';
        String Description = 'Emits an event on a configurable hourly basis.'; //Swallows regular un-scheduled heartbeat messages
        String Icon = 'clock';
        String StepConfig = ScheduleStepConfig__c.class.getName();
        Boolean ConsumesHeartbeat = true;
        Integer Chunks = 100; //no soqls, no dmls
        Map<String,String> Inputs = new Map<String,String>{
            'EntryPointTimestamp' => 'DATETIME of the point in time this schedule was intended to run.'
        };
        public String Cardinality = 'One';
    }
    
    public class ServiceException extends Exception {}
    
    override public List<Map<String,Object>> execute(Map<String,Object> inputEvent) {
        
        String recordId = (String)inputEvent.get('RecordId');
        //if (recordId == null) throw new ServiceException('Null record id.'); //TODO (schedule does not necessarily contain heartbeat)
        
        Id stepConfigId = (String)inputEvent.get('StepConfigId');
        if (stepConfigId == null) throw new ServiceException('Null step config id.');
        
        String stampAsString = (String)inputEvent.get('EntryPointTimestamp');
        if (stampAsString == null) throw new ServiceException('Null entry point timestamp.');
        
        Boolean wasHeartbeat = false;
        if (recordId != null) wasHeartbeat = recordId.startsWith('08e'); //#810

        List<Map<String,Object>> outputEvents = new List<Map<String,Object>>();
    
        if (wasHeartbeat == true) {
            
            ScheduleStepConfig__c config;
            List<ScheduleStepConfig__c> scheduleStepConfigs = ScheduleStepConfig__c.getAll().values(); //fetch without using soql
            for (ScheduleStepConfig__c scheduleStepConfig : scheduleStepConfigs) if (scheduleStepConfig.Id == stepConfigId) config = scheduleStepConfig;
            
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

    @TestVisible static Boolean isWithinWindow(String stampAsString, ScheduleStepConfig__c config) {
        DateTime stampAsDateTime;
        try {
           stampAsString =  getISO8601(stampAsString);
           stampAsDateTime = getStamp(stampAsString);
        } catch (NullPointerException e)  {
            throw new ServiceException('Problem with getISO8601 or getStamp("' + stampAsString + '")', e);
        }

        Set<String> runTimes = new Set<String>();
        if (config.Is0000__c) runTimes.add('00:00');
        if (config.Is0100__c) runTimes.add('01:00');
        if (config.Is0200__c) runTimes.add('02:00');
        if (config.Is0300__c) runTimes.add('03:00');
        if (config.Is0400__c) runTimes.add('04:00');
        if (config.Is0500__c) runTimes.add('05:00');
        if (config.Is0600__c) runTimes.add('06:00');
        if (config.Is0700__c) runTimes.add('07:00');
        if (config.Is0800__c) runTimes.add('08:00');
        if (config.Is0900__c) runTimes.add('09:00');
        if (config.Is1000__c) runTimes.add('10:00');
        if (config.Is1100__c) runTimes.add('11:00');
        if (config.Is1200__c) runTimes.add('12:00');
        if (config.Is1300__c) runTimes.add('13:00');
        if (config.Is1400__c) runTimes.add('14:00');
        if (config.Is1500__c) runTimes.add('15:00');
        if (config.Is1600__c) runTimes.add('16:00');
        if (config.Is1700__c) runTimes.add('17:00');
        if (config.Is1800__c) runTimes.add('18:00');
        if (config.Is1900__c) runTimes.add('19:00');
        if (config.Is2000__c) runTimes.add('20:00');
        if (config.Is2100__c) runTimes.add('21:00');
        if (config.Is2200__c) runTimes.add('22:00');
        if (config.Is2300__c) runTimes.add('23:00');
        
        return isTimeMatch(stampAsString, runTimes);
    }
 
    @TestVisible static Boolean isTimeMatch(String stampAsString, Set<String> runTimes) {
        Pattern myPattern = pattern.compile('.*T(\\d{2}:\\d{2}):\\d{2}.*');  // '2014-01-18T12:00:00.000Z'
        Matcher myMatcher = myPattern.matcher(stampAsString);
        if ( myMatcher.matches() && (myMatcher.groupCount() == 1)) {
            return runTimes.contains(myMatcher.group(1));
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