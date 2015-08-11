@IsTest public class MessageDataExtensionTest {
    
    static testmethod void coverCode() {
        //arrange
        ApexPages.StandardController controller = new ApexPages.StandardController(new Message__c());
        MessageDataExtension extension = new MessageDataExtension(controller);
        
        //act
        extension.doRedirect();
        
        //assert
        System.assert(ApexPages.hasMessages(), 'Wrong messages.');
    }
    
}