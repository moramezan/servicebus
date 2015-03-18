@IsTest public class MessageRestartExtensionTest {

    static testmethod void testDoRestartRunsBroker() {
        //arrange broker implementation
        insert new BrokerSetting__c(BrokerClassName__c = SynchronousBroker.class.getName());
        
        //arrange message
        List<Message__c> messages = new Job('Test', UserInfo.getUserId()).persist();
        
        //arrange controller and extension
        ApexPages.StandardController controller = new ApexPages.StandardController(messages[0]);
        MessageRestartExtension extension = new MessageRestartExtension(controller);
        MessageRestartExtension.message = messages[0];
        MessageRestartExtension.message.Status__c = 'Started';
        
        //act
        extension.doRestart();
        
        //assemble
        MessageRestartExtension.message = [SELECT Id, Exception__c FROM Message__c WHERE Id = :MessageRestartExtension.message.Id];
        
        //assert
        String expectedMessage = 'Step unqueryable, eg bad sequence name, position, missing terminate.';
        String actualMessage = MessageRestartExtension.message.Exception__c;
        System.assertEquals(expectedMessage, actualMessage);
    }
    
    static testmethod void testDoRestartLeavesCompletedAndBufferedMessages() {
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
        MessageRestartExtension extension = new MessageRestartExtension(controller);
        MessageRestartExtension.message = messages[0];
        
        //act
        extension.doRestart();
        
        //assert
        System.assert(ApexPages.hasMessages());
    }

}