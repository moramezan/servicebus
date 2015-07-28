@IsTest public class MessageRestartExtensionTest {

    static testmethod void testDoRestartRunsBroker() {
        //arrange broker implementation
        insert new BrokerSetting__c(BrokerClassName__c = BrokerTest.SynchronousBroker.class.getName());
        
        //arrange sequence and step
        insert new Sequence__c(Name = 'Test');
        SequenceModel model = SequenceModel.fromName('Test');
        model.appendStep(Terminate.class.getName());
        
        //arrange message
        List<Message__c> messages = new Job('Test', UserInfo.getUserId()).persist();
        messages = Broker.impl().locateMarkableWork();
        messages[0].Exception__c = 'Some exception...';
        update messages; //saves away fully qualified class name
        
        //arrange controller and extension
        ApexPages.StandardController controller = new ApexPages.StandardController(messages[0]);
        MessageRestartExtension extension = new MessageRestartExtension(controller);
        
        //act
        extension.doRestart();
        
        //assert
        System.assert(!ApexPages.hasMessages(), 'Page should not have messages.');
        System.assert(Broker.IsFirstRun, 'Broker not run.');
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
        
        //act
        extension.doRestart();
        
        //assert
        System.assert(ApexPages.hasMessages());
    }

}