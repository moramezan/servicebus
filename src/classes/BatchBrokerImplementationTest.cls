@isTest public class BatchBrokerImplementationTest {
 
    static testMethod void callingRestartSuccessfullyCallsRestartImp() {
        //arrange processes
        Process__c markProcess = Processes.generateOne(Mark.class);
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        
        //arrange sequence
        String sequenceNameA = 'sequenceA';
        Sequence__c sequenceA = new Sequence__c(Name = sequenceNameA);
        insert sequenceA;
        
        //arrange steps
        Step__c stepA1 = Steps.generateOne(sequenceA.Id, markProcess.Id);
        Step__c stepA2 = Steps.generateOne(sequenceA.Id, terminateProcess.Id);
        Decimal positionA1 = stepA1.Position__c;
        Decimal positionA2 = stepA2.Position__c;
        
        //arrange specific broker implementation
        insert new BrokerSettings__c(BrokerClassName__c = BatchBrokerImplementation.class.getName());
        
        //act (will synchronously start() execute() finish() and reschedule too)
        Test.startTest();
        Broker.enqueue(sequenceNameA, '000000000000000AAA');
        Test.stopTest();
        
        //assert
        Integer expectedCount = 0;
        Integer actualCount = [SELECT COUNT() FROM Message__c WHERE IsDeleted =  false ALL ROWS];
        System.assertEquals(expectedCount, actualCount);
 
    }
    
    static testMethod void callingEnqueueWithInternallyFailingPluginSuccessfullyWritesErrorMessageToMessage() {
        //arrange processes
        Process__c failureProcess = Processes.generateOne(BrokerTest.FailurePlugin.class);
        
        //arrange sequence
        String  sequenceNameA = 'sequenceA';
        Sequence__c sequenceA = new Sequence__c(Name = sequenceNameA);
        insert sequenceA;
        
        //arrange step
        Step__c stepA1 = Steps.generateOne(sequenceA.Id, failureProcess.Id);
        Decimal positionA1 = stepA1.Position__c;
        
        //arrange specific broker implementation
        insert new BrokerSettings__c(BrokerClassName__c = BatchBrokerImplementation.class.getName());
 
        //act (will synchronously start() execute() finish() and reschedule too)
        Test.startTest();
        Broker.enqueue(sequenceNameA, '000000000000000AAA');
        Test.stopTest();
        
        //assemble
        List<Message__c> messages = [
            SELECT Id, Name, Process__r.FullyQualifiedClassName__c, Step__c , Status__c, Exception__c, IsDeleted
            FROM Message__c
            WHERE IsDeleted =  false
            ALL ROWS
        ];
        Integer actualCount = messages.size();
        
        //assert
        Integer expectedCount = 1;
        System.assertEquals(expectedCount, actualCount);
        
        String expectedProcessName = BrokerTest.FailurePlugin.class.getName();
        System.assertEquals(expectedProcessName, messages[0].Process__r.FullyQualifiedClassName__c);
        
        String expectedMessage = BrokerTest.FailureMessage;
        System.assertEquals(expectedMessage, messages[0].Exception__c);
    }

    static testMethod void callingBrokerStartSuccessfullyCallsStartImp() {
        //arrange processes
        Process__c markProcess = Processes.generateOne(Mark.class);
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        
        //arrange sequence
        String  sequenceNameA = 'sequenceA';
        Sequence__c sequenceA = new Sequence__c(Name = sequenceNameA);
        insert sequenceA;
        
        //arrange steps
        Step__c stepA1 = Steps.generateOne(sequenceA.Id, markProcess.Id);
        Step__c stepA2 = Steps.generateOne(sequenceA.Id, terminateProcess.Id);
        Decimal positionA1 = stepA1.Position__c;
        Decimal positionA2 = stepA2.Position__c;
        
        //arrange specific broker implementation
        insert new BrokerSettings__c(BrokerClassName__c = BatchBrokerImplementation.class.getName());
        
        //scenario:
        //resolved state, assume manual intervention to set status to 'Reprocess'
        Map<String,Object> parameters = new Map<String,Object> {
            'eda_SequenceName' => sequenceNameA,
            'eda_Position' => 1, //not zero !!!
            'Id' => '000000000000000AAA'
        };
        Message__c message = new Message__c(
            Step__c = stepA1.Id,
            Status__c = 'Reprocess',
            Parameters__c = Json.serializePretty(parameters)
        );
        insert message;
        
        //act
        Test.startTest();
        new BatchBrokerImplementation().restartIfWorkPending();
        Test.stopTest();
        
        //assert
        Integer expectedCount = 0;
        Integer actualCount = [SELECT COUNT() FROM Message__c WHERE IsDeleted = false ALL ROWS];
        System.assertEquals(expectedCount, actualCount);
    }
    
}