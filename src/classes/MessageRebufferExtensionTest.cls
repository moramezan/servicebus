@IsTest public class MessageRebufferExtensionTest {

    static testmethod void testDoRebufferRunsBroker() {
        //arrange message
        List<Message__c> messages = new Job('Test', UserInfo.getUserId()).persist();
        
        //arrange controller and extension
        ApexPages.StandardController controller = new ApexPages.StandardController(messages[0]);
        MessageRebufferExtension extension = new MessageRebufferExtension(controller);
        MessageRebufferExtension.message = messages[0];
        MessageRebufferExtension.message.Status__c = 'Started';
        
        //act
        try {
            extension.doRebuffer();
            System.assert(false, 'Line above should throw exception');
        } catch (Broker.EngineException e) {
            String expectedMessage = 'Step unqueryable, eg bad sequence name, position, missing terminate.';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage);
        }
    }
    
    static testmethod void testDoRebufferLeavesCompletedAndBufferedMessages() {
        //TODO
        //input should go from Started to Completed
        //outputs should be persisted as Buffered
        //real broker should get restarted!!! 
    }
    
    static testmethod void testNonStartedLeavesMessage() {
        //arrange message
        List<Message__c> messages = new Job('Test', UserInfo.getUserId()).persist();
        
        //arrange controller and extension
        ApexPages.StandardController controller = new ApexPages.StandardController(messages[0]);
        MessageRebufferExtension extension = new MessageRebufferExtension(controller);
        MessageRebufferExtension.message = messages[0];
        
        //act
        extension.doRebuffer();
        
        //assert
        System.assert(ApexPages.hasMessages());
    }

}