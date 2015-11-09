@IsTest class MessagePauseQueueExtensionTest {
    
    static testmethod void coverCode() {
        //arrange controller and extension
        ApexPages.StandardSetController controller = new ApexPages.StandardSetController(new List<Message__c>());
        MessagePauseQueueExtension extension = new MessagePauseQueueExtension(controller);
        
        //act
        extension.doPause();
        
        //assert
        System.assert(!ApexPages.hasMessages(), 'Wrong messages.');
    }
    
}