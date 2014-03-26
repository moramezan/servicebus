public with sharing class Schedule implements Process.Plugin {
    
    public class Meta {
        public String Icon = 'clock';
        public SObject ConfigObject = ScheduleConfiguration__c.SObjectType.newSObject();
        public String DocsPageUrl = Page.ScheduleConfigurationHelp.getUrl();
    }
    
    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
        plugin.Tag = 'Event Driven Architecture';
        plugin.Name = 'Schedule';
        Plugin.Description = 'Fires this sequence at controlled intervals';
        return plugin;
    }
    
    public Process.PluginResult invoke(Process.PluginRequest request) {
        Map<String,Object> parameters = request.inputParameters;
        List<Map<String,Object>> parametersList = new List<Map<String,Object>>();
        
        Boolean isPassThru = String.isBlank((String)parameters.get('eda_Heartbeat'));
        
        if (isPassThru) {
            parametersList.add(parameters);
        } else {
            //DateTime is not a primitive Object
            DateTime heartbeat = (DateTime)Json.deserialize('"' + (String)parameters.get('eda_Heartbeat') + '"', DateTime.class);
            
            ScheduleConfiguration__c config = [
                SELECT Id, Frequency__c, FriendlyDates__c, FriendlyTimes__c
                FROM ScheduleConfiguration__c
                WHERE Id = :(Id)parameters.get('eda_ConfigObjectId')
            ];
            
            if (isWithinWindow(heartbeat, config)) {
                //this is one of the configured times, so carry on to next step
                parametersList.add(parameters);
            }
        }
        return EdaUtility.convert(parametersList);
    }
    
    @testVisible static private Boolean isWithinWindow(DateTime heartbeat, ScheduleConfiguration__c config) {
        String frequency = config.Frequency__c;
        Set<String> details = new Set<String>(config.FriendlyDates__c.split(';'));
        Set<String> runTimes = new Set<String>(config.FriendlyTimes__c.split(';'));
        
        if (frequency == 'Daily') {
            if (isWithinDailyWindow(heartbeat, details) && isWithinHourlyWindow(heartbeat, runTimes)) {
                //&& isWithinMinutelyWindow() && isWithinSecondlyWindow()
                return true;
            }
        } else if (frequency == 'Weekly') {
            if (isWithinWeeklyWindow(heartbeat, details) && isWithinHourlyWindow(heartbeat, runTimes)) {
                //&& isWithinMinutelyWindow() && isWithinSecondlyWindow()
                return true;
            }
        } else if (frequency == 'Monthly') {
            if (isWithinMonthlyWindow(heartbeat, details) && isWithinHourlyWindow(heartbeat, runTimes)) {
                //&& isWithinMinutelyWindow() && isWithinSecondlyWindow()
                return true;
            }
        }
        
        return false;
    }
    
    @testVisible static private Boolean isWithinDailyWindow(DateTime heartbeat, Set<String> details) {
        String day = heartbeat.format('EEEE');
        
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
    
    @testVisible static private Boolean isWithinWeeklyWindow(DateTime heartbeat, Set<String> details) {
        String day = heartbeat.formatGmt('EEEE');
        return details.contains(day);
    }
    
    @testVisible static private Boolean isWithinMonthlyWindow(DateTime heartbeat, Set<String> details) {
        //convert ['1', '2', '3'] to [1, 2, 3]
        Set<Integer> days = new Set<Integer>();
        for (String detail : details) days.add(Integer.valueOf(detail));
        Integer today = heartbeat.dayGmt();
        return days.contains(today);
    }
    
    @testVisible static private Boolean isWithinHourlyWindow(DateTime heartbeat, Set<String> runTimes) {
        //convert ['01:00', '02:00', '03:00'] to [1:00, 2:00, 3:00]
        Set<Time> times = new Set<Time>();
        for (String runTime : runTimes) times.add(Time.newInstance(Integer.valueOf(runTime.left(2)), 0, 0, 0));
        Time hour = heartbeat.timeGmt();
        return times.contains(hour);
    }
    
}