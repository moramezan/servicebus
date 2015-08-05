@IsTest public class MessageProcessExtensionTest {

    static testmethod void coverCode() {
        //arrange message
        Message__c message = new Message__c();
        insert message;
        
        //arrange controller, extension
        ApexPages.StandardController controller = new ApexPages.StandardController(message);
        MessageProcessExtension extension = new MessageProcessExtension(controller);
        
        //act
        PageReference pr = extension.showProcess();
        
        //assert
        System.assert(ApexPages.hasMessages());
    }
    
}