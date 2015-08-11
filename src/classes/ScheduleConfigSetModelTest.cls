@IsTest public class ScheduleConfigSetModelTest {
    
    static testmethod void testDailyFriendlyNames() {
        //act every hour of every day
        insert new ScheduleConfig__c(
            IsActive__c = true,
            Frequency__c = 'Daily',
            FriendlyTimes__c = '00:00;01:00;02:00;03:00;04:00;05:00;06:00;07:00;08:00;09:00;10:00;11:00;12:00;13:00;14:00;15:00;16:00;17:00;18:00;19:00;20:00;21:00;22:00;23:00',
            FriendlyDates__c = 'Working days only;Weekends and holidays'
        );
        
        //assemble
        ScheduleConfig__c config = [SELECT Name FROM ScheduleConfig__c];
        
        //assert
        String expectedName = 'Fires this sequence every hour every day.';
        String actualName = config.Name;
        System.assertEquals(expectedName, actualName);
    }
    
    static testmethod void testWeeklyFriendlyNames() {
        //act twice a day
        insert new ScheduleConfig__c(
            IsActive__c = true,
            Frequency__c = 'Weekly',
            FriendlyTimes__c = '09:00;17:00',
            FriendlyDates__c = 'Monday;Friday'
        );
        
        //assemble
        ScheduleConfig__c config = [SELECT Name FROM ScheduleConfig__c];
        
        //assert
        String expectedName = 'Fires this sequence at 09:00, 17:00 on Mondays and Fridays.';
        String actualName = config.Name;
        System.assertEquals(expectedName, actualName);
    }
    
    static testmethod void testMonthlyFriendlyNames() {
        //act twice a month
        insert new ScheduleConfig__c(
            IsActive__c = true,
            Frequency__c = 'Monthly',
            FriendlyTimes__c = '12:00',
            FriendlyDates__c = '07;14'
        );
        
        //assemble
        ScheduleConfig__c config = [SELECT Name FROM ScheduleConfig__c];
        
        //assert
        String expectedName = 'Fires this sequence at 12:00 on day 14, 07 of every month.';
        String actualName = config.Name;
        System.assertEquals(expectedName, actualName);
    }
    
}