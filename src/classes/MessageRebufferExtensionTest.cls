@IsTest public class MessageRebufferExtensionTest {

    static testmethod void testDml() {
        //arrange message
        Message__c message = new Message__c(Status__c = 'Queued');
        insert message;
        
        //arrange controller and extension
        ApexPages.StandardController controller = new ApexPages.StandardController(message);
        MessageRebufferExtension extension = new MessageRebufferExtension(controller);
        MessageRebufferExtension.message = message;
        
        //act
        new MessageRebufferExtension.DoDml();
        
        //assert
        String expectedStatus = 'Rebuffered';
        String actualStatus = message.Status__c;
        System.assertEquals(expectedStatus, actualStatus);
    }

}