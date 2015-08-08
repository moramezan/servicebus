@IsTest private class MessagePauseQueueExtensionTest {
    
    static testmethod void callingDoDmlCtorCorrectlySetsPauseFlag() {
        // arrange
        Boolean isPaused =  false;
        insert new BrokerSetting__c(IsPaused__c = isPaused);
        
        //act - actions in the ctor
        MessagePauseQueueExtension.DoDml doDmlInstance = new MessagePauseQueueExtension.DoDml();
        
        //assemble
        BrokerSetting__c actualSettings  = BrokerSetting__c.getInstance();
        Boolean actualIsPaused =  actualSettings.IsPaused__c;

        // assert
        Boolean expectedIsPaused =  true;
        System.assertEquals( expectedIsPaused, actualIsPaused);
    }
    
    
   static testmethod void  callingDoPauseOnPausedMessagesPausesQueue() {
        // arrange
        Boolean isPaused =  false;
        insert new BrokerSetting__c(IsPaused__c = isPaused);
        
        //act
        List<Message__c> messages = [SELECT Id FROM Message__c];
        ApexPages.StandardSetController controller = new ApexPages.StandardSetController(messages);
        MessagePauseQueueExtension messagePauseQueueExtension =  new MessagePauseQueueExtension(controller);
        System.PageReference actualPageReference  = messagePauseQueueExtension.doPause();
        
        //assemble
        BrokerSetting__c actualSettings  = BrokerSetting__c.getInstance();
        Boolean actualIsPaused =  actualSettings.IsPaused__c;
        
        
        // assert
        Boolean expectedIsPaused =  (!isPaused);
        System.assertEquals( expectedIsPaused, actualIsPaused);
    }
}