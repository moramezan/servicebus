public class ScheduleConfigObjectSet extends SalesforceObjectSet {
    
    public ScheduleConfigObjectSet(List<ScheduleConfig__c> sobjects) {
        super(sobjects);
    }
    
    private void populateFriendlyNames() {
        List<ScheduleConfig__c> scheduleConfigs = (List<ScheduleConfig__c>)this.getSObjects();
        Set<String> everyHour = new Set<String>{'00:00','01:00','02:00','03:00','04:00','05:00','06:00','07:00','08:00','09:00','10:00','11:00','12:00','13:00','14:00','15:00','16:00','17:00','18:00','19:00','20:00','21:00','22:00','23:00'};
        Set<String> allDaily = new Set<String>{'Working days only','Weekends and holidays'};
        Set<String> allWeekly = new Set<String>{'Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'};
        Set<String> allMonthly = new Set<String>{'01','02','03','04','05','06','07','08','09','10','11','12','13','14','15','16','17','18','19','20','21','22','23','24','25','26','27','28','29','30'};
     
        for (ScheduleConfig__c scheduleConfig : scheduleConfigs) {
            List<String> friendlyTimes = new List<String>();
            List<String> friendlyDates = new List<String>();
            if (null != scheduleConfig.FriendlyTimes__c) friendlyTimes = scheduleConfig.FriendlyTimes__c.split(';');
            if (null != scheduleConfig.FriendlyDates__c) friendlyDates = scheduleConfig.FriendlyDates__c.split(';');
            
            String name = 'Fires this sequence ';
            
            //hourly
            if (new Set<String>(friendlyTimes).containsAll(everyHour)) {
                name += 'every hour ';
            } else {
                name += 'at ';
                name += String.join(friendlyTimes, ', ');
                name += ' ';
            }
            
            //daily
            if ('Daily' == scheduleConfig.Frequency__c) {
                if (new Set<String>(friendlyDates).containsAll(allDaily)) {
                    name += 'every day.';
                } else {
                    name += 'on ';
                    name += String.join(friendlyDates, ', ').toLowerCase();
                    name += '.';
                }
            }
            
            //weekly
            if ('Weekly' == scheduleConfig.Frequency__c) {
                if (new Set<String>(friendlyDates).containsAll(allWeekly)) {
                    name += 'every day of the week.';
                } else {
                    name += 'on ';
                    //if (friendlyDates.size() > 1) friendlyDates[friendlyDates.size() - 1] = 'and ' + friendlyDates[friendlyDates.size() - 1];
                    name += String.join(friendlyDates, 's and ');
                    name += 's.';
                }
            }
            
            //monthly
            if ('Monthly' == scheduleConfig.Frequency__c) {
                if (new Set<String>(friendlyDates).containsAll(allMonthly)) {
                    name += 'every day of the month.';
                } else {
                    name += 'on day ';
                    name += String.join(friendlyDates, ', ');
                    name += ' ';
                    name += 'of every month.';
                }
            }
            scheduleConfig.Name = name.left(80);
        }
    }
    
    override public void onBeforeUpdate(List<SObject> sobjects) {
        this.populateFriendlyNames();
    }
    
    override public void onBeforeInsert() {
        this.populateFriendlyNames();
    }

}