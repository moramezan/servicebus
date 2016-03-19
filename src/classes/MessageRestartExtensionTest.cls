@IsTest class MessageRestartExtensionTest {
    
    static testmethod void coverCode() {
        //arrange
        ApexPages.StandardSetController controller = new ApexPages.StandardSetController(new List<Message__c>());
        MessageRestartExtension extension = new MessageRestartExtension(controller);
        
        //act
        extension.doRestart();
        
        //assert
        System.assert(ApexPages.hasMessages(), 'Wrong messages.');
    }
    
}