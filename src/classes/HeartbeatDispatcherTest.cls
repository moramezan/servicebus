@IsTest private class HeartbeatDispatcherTest {
    
    static testmethod void coverExecuteMethod() {
        //arrange specific broker implementation
        insert new BrokerSettings__c(BrokerClassName__c = SynchronousBroker.class.getName());
        
        //act
        Test.startTest();
        HeartbeatDispatcher dispatcher = new HeartbeatDispatcher();
        System.schedule('HeartbeatDispatcherTest', '0 0 * * * ?', dispatcher);
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
        Integer actualCount = [SELECT COUNT() FROM AsyncApexJob WHERE ApexClass.Name = 'HeartbeatDispatcher'];
        System.assertEquals(expectedCount, actualCount);
    }
    
}