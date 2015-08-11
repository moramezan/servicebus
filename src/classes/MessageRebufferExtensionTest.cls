@IsTest public class MessageRebufferExtensionTest {
    
    static testmethod void coverCode() {
        //arrange
        ApexPages.StandardSetController controller = new ApexPages.StandardSetController(new List<Message__c>());
        MessageRebufferExtension extension = new MessageRebufferExtension(controller);
        
        //act
        extension.doRebuffer();
        
        //assert
        System.assert(ApexPages.hasMessages(), 'Wrong messages.');
    }
    
}