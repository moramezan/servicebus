@IsTest public class MessageRebufferExtensionTest {

    static testmethod void testDml() {
        //arrange message
        List<Message__c> messages = new Job('Test', UserInfo.getUserId()).persist();
        
        //arrange controller and extension
        ApexPages.StandardController controller = new ApexPages.StandardController(messages[0]);
        MessageRebufferExtension extension = new MessageRebufferExtension(controller);
        MessageRebufferExtension.message = messages[0];
        
        //act
        new MessageRebufferExtension.DoDml();
        
        //assert
        String expectedStatus = 'Rebuffered';
        String actualStatus = messages[0].Status__c;
        System.assertEquals(expectedStatus, actualStatus);
    }

}