@isTest private class ScheduleDispatcherTest {
	
    static testMethod void coverExecuteMethod() {
        Test.startTest();
        ScheduleDispatcher dispatcher = new ScheduleDispatcher();
        System.schedule('ScheduleDispatcherTest', '0 0 * * * ?', dispatcher);
        //at 0 seconds
        //at 0 minutes
        //every hour
        //on every day of the month
        //on every month of the year
        //any day of the week
        //[optional year]
        dispatcher.execute(null);
        Test.stopTest();
        
        Integer expectedCount = 1;
        Integer actualCount = [SELECT COUNT() FROM AsyncApexJob];
        System.assertEquals(expectedCount, actualCount);
    }
    
}