@IsTest class MessageListExtensionTest {
    
    static testmethod void coverCode() {
        //arrange
        ApexPages.StandardSetController setController = new ApexPages.StandardSetController(new List<Message__c>());
        
        //act
        MessageListExtension extension = new MessageListExtension(setController);
        
        //assert
        System.assert(!ApexPages.hasMessages());
    }
    
}