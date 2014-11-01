@IsTest public class VerticalBrokerImplementationTest {

    static testmethod void testMarkAndExecuteAndDoneConditions() {
        //arrange specific broker implementation
        insert new BrokerSettings__c(BrokerClassName__c = VerticalBrokerImplementation.class.getName());
        
        //arrange processes
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        
        //arrange sequence
        Sequence__c sequence = new Sequence__c(Name = 'TestSequence');
        insert sequence;
        
        //arrange steps
        Step__c step = StepObject.generateOne(sequence.Id, terminateProcess.Id);
        
        //arrange message
        Message__c message = new Message__c(
            Status__c = 'Buffered',
            Parameters__c = Json.serialize(new Map<String,Object> {
                'eda_SequenceName' => 'TestSequence',
                'eda_Position' => 0
            })
        );
        insert message;
        
        //act (enqueue)
        VerticalBrokerImplementation impl = (VerticalBrokerImplementation)Broker.impl();
        List<Boolean> scopes = new List<Boolean>{true};
        impl.resolve(new List<Message__c>{message});
        update message;
        
        //assert
        Integer expectedCount = 1;
        Integer actualCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Buffered'];
        System.assertEquals(expectedCount, actualCount, 'Message should be buffered.');
        
        //act (mark)
        impl.execute(null, scopes);
        
        //assert
        expectedCount = 1;
        actualCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Started'];
        System.assertEquals(expectedCount, actualCount, 'Message should be started.');
        System.assert(!impl.abortJob, 'Job should not be aborted.');
        
        //act (execute)
        Id messageId = [SELECT Id FROM Message__c WHERE Status__c = 'Started'].Id;
        System.debug(SalesforceObject.getById(step.Id));
        impl.execute(null, scopes);
        
        //assert
        expectedCount = 1;
        actualCount = [SELECT COUNT() FROM Message__c WHERE Status__c = 'Completed'];
        System.assertEquals(expectedCount, actualCount, 'Message should be completed.');
        System.assert(!impl.abortJob, 'Job should not be aborted.');
        
        //act (done)
        impl.execute(null, scopes);
        System.assert(impl.abortJob, 'Job should be aborted.');
    }

}