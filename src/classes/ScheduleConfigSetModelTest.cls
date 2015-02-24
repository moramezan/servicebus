@IsTest public class ScheduleConfigSetModelTest {
    
    static testmethod void testDailyFriendlyNames() {
        //arrange an all day every day schedule
        ScheduleConfig__c config = new ScheduleConfig__c(
            Frequency__c = 'Daily',
            FriendlyTimes__c = '00:00;01:00;02:00;03:00;04:00;05:00;06:00;07:00;08:00;09:00;10:00;11:00;12:00;13:00;14:00;15:00;16:00;17:00;18:00;19:00;20:00;21:00;22:00;23:00',
            FriendlyDates__c = 'Working days only;Weekends and holidays'
        );
        
        //act
        insert config;
        
        //assemble
        config = [SELECT Name FROM ScheduleConfig__c WHERE Id = :config.Id];
        
        //assert
        String expectedName = 'Fires this sequence every hour every day.';
        String actualName = config.Name;
        System.assertEquals(expectedName, actualName);
    }
    
    static testmethod void testWeeklyFriendlyNames() {
        //arrange an all day every day schedule
        ScheduleConfig__c config = new ScheduleConfig__c(
            Frequency__c = 'Weekly',
            FriendlyTimes__c = '09:00;17:00',
            FriendlyDates__c = 'Monday;Friday'
        );
        
        //act
        insert config;
        
        //assemble
        config = [SELECT Name FROM ScheduleConfig__c WHERE Id = :config.Id];
        
        //assert
        String expectedName = 'Fires this sequence at 09:00, 17:00 on Mondays and Fridays.';
        String actualName = config.Name;
        System.assertEquals(expectedName, actualName);
    }
    
    static testmethod void testMonthlyFriendlyNames() {
        //arrange an all day every day schedule
        ScheduleConfig__c config = new ScheduleConfig__c(
            Frequency__c = 'Monthly',
            FriendlyTimes__c = '12:00',
            FriendlyDates__c = '07;14;21;28'
        );
        
        //act
        insert config;
        
        //assemble
        config = [SELECT Name FROM ScheduleConfig__c WHERE Id = :config.Id];
        
        //assert
        String expectedName = 'Fires this sequence at 12:00 on day 14, 21, 28, 07 of every month.';
        String actualName = config.Name;
        System.assertEquals(expectedName, actualName);
    }
    
}