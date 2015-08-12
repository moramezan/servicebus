@IsTest public class MessageRecordDataExtensionTest {
    
    static testmethod void coverCode() {
        //arrange message
        Message__c message = new Message__c();
        insert message;
        
        //act
        ApexPages.StandardController controller = new ApexPages.StandardController(message);
        MessageRecordDataExtension extension = new MessageRecordDataExtension(controller);
        extension.showRecordData();
        
        //assert
        System.assert(!ApexPages.hasMessages(), 'Wrong messages.');
    }
    
}