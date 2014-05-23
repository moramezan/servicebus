@IsTest private class MessagePauseQueueExtensionTest {
    
    static testmethod void callingDoDmlCtorCorrectlySetsPauseFlag() {
        // arrange
        Boolean isPaused =  false;
        insert new BrokerSettings__c(BrokerClassName__c = SynchronousBroker.class.getName(), IsPaused__c = isPaused);
        
        //act - actions in the ctor
        MessagePauseQueueExtension.DoDml doDmlInstance = new MessagePauseQueueExtension.DoDml();
        
        //assemble
        BrokerSettings__c actualSettings  = BrokerSettings__c.getInstance();
        Boolean actualIsPaused =  actualSettings.IsPaused__c;

        // assert
        Boolean expectedIsPaused =  true;
        System.assertEquals( expectedIsPaused, actualIsPaused);
    }
    
    
   static testmethod void  callingDoPauseOnQueuedMessagesProcessesMessages() {
        // arrange
        Boolean isPaused =  false;
        insert new BrokerSettings__c(BrokerClassName__c = SynchronousBroker.class.getName(), IsPaused__c = isPaused);
        
        //act 
        ApexPages.StandardSetController controller = new ApexPages.StandardSetController([SELECT Id, Name FROM Message__c]);
        MessagePauseQueueExtension messagePauseQueueExtension =  new MessagePauseQueueExtension(controller);
        System.PageReference actualPageReference  = messagePauseQueueExtension.doPause();
        
        //assemble
        BrokerSettings__c actualSettings  = BrokerSettings__c.getInstance();
        Boolean actualIsPaused =  actualSettings.IsPaused__c;
        
        
        // assert
        Boolean expectedIsPaused =  (!isPaused);
        System.assertEquals( expectedIsPaused, actualIsPaused);
        String expectedPageReference = SObjectType.Message__c.KeyPrefix;
        System.Assert(actualPageReference.getUrl().contains(expectedPageReference));
    }
}