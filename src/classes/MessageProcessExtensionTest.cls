@IsTest public class MessageProcessExtensionTest {

    static testmethod void testDml() {
        //arrange message
        Message__c message = new Message__c(Status__c = 'Queued');
        insert message;
        
        //arrange controller and extension
        ApexPages.StandardController controller = new ApexPages.StandardController(message);
        MessageProcessExtension extension = new MessageProcessExtension(controller);
        MessageProcessExtension.message = message;
        
        //act
        new MessageProcessExtension.DoDml();
        
        //assert
        String expectedStatus = 'Rebuffered';
        String actualStatus = message.Status__c;
        System.assertEquals(expectedStatus, actualStatus);
    }

}