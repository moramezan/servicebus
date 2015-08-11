@IsTest private class MessageResumeQueueExtensionTest {
    
    static testmethod void coverCode() {
        //arrange controller and extension
        ApexPages.StandardSetController controller = new ApexPages.StandardSetController(new List<Message__c>());
        MessageResumeQueueExtension extension = new MessageResumeQueueExtension(controller);
        
        //act
        extension.doResume();
        
        //assert
        System.assert(!ApexPages.hasMessages(), 'Wrong messages.');
    }
    
}