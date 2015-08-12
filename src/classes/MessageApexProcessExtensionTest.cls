@IsTest public class MessageApexProcessExtensionTest {
    
    static testmethod void coverCode() {
        //arrange record
        Message__c message = new Message__c();
        insert message;
        
        //act
        ApexPages.StandardController controller = new ApexPages.StandardController(message);
        MessageApexProcessExtension extension = new MessageApexProcessExtension(controller);
        extension.showApexProcess();
        
        //assert
        System.assert(ApexPages.hasMessages());
    }
    
}