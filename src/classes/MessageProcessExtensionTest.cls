@IsTest public class MessageProcessExtensionTest {
    
    static testmethod void coverCode() {
        //arrange record
        Message__c message = new Message__c();
        insert message;
        
        //act
        ApexPages.StandardController controller = new ApexPages.StandardController(message);
        MessageProcessExtension extension = new MessageProcessExtension(controller);
        extension.showProcess();
        
        //assert
        System.assert(ApexPages.hasMessages());
    }
    
}