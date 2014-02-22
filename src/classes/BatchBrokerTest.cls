@isTest public class BatchBrokerTest {
 
    static testMethod void callingRestartSuccessfullyCallsRestartImp() {
        //arrange processes
        Process__c markProcess = Processes.generateOne(Mark.class);
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        
        //arrange chain
        String chainNameA = 'chainA';
        Chain__c chainA = new Chain__c(Name = chainNameA);
        insert chainA;
        
        //arrange steps
        Step__c stepA1 = Steps.generateOne(chainA.Id, markProcess.Id);
        Step__c stepA2 = Steps.generateOne(chainA.Id, terminateProcess.Id);
        Decimal sequenceA1 = stepA1.Sequence__c;
        Decimal sequenceA2 = stepA2.Sequence__c;
        
        //arrange specific broker implementation
        insert new BrokerSettings__c(BrokerClassName__c = BatchBroker.class.getName());
        
        //act (will synchronously start() execute() finish() and reschedule too)
        Test.startTest();
        Broker.enqueue(chainNameA, '000000000000000AAA');
        Test.stopTest();
        
        //assemble
        List<Message__c> messages = [
            SELECT Id, Name, Process__r.Name, Step__c , Status__c, IsDeleted
            FROM Message__c
            WHERE IsDeleted =  false
            ALL ROWS
        ];
        
        Integer actualCount = messages.size();
        
        //assert
        Integer expectedCount = 0;
        System.assertEquals(expectedCount , actualCount);
 
    }
    
    static testMethod void callingEnqueueWithInternallyFailingPluginSuccessfullyWritesErrorMessageToMessage() {
        //arrange processes
        Process__c failureProcess = Processes.generateOne(FailurePlugin.class);
        
        //arrange chain
        String  chainNameA = 'chainA';
        Chain__c chainA = new Chain__c(Name = chainNameA);
        insert chainA;
        
        //arrange step
        Step__c stepA1 = Steps.generateOne(chainA.Id, failureProcess.Id);
        Decimal sequenceA1 = stepA1.Sequence__c;
        
        //arrange specific broker implementation
        insert new BrokerSettings__c(BrokerClassName__c = BatchBroker.class.getName());
 
        //act (will synchronously start() execute() finish() and reschedule too)
        Test.startTest();
        Broker.enqueue(chainNameA, '000000000000000AAA');
        Test.stopTest();
        
        //assemble
        List<Message__c> messages = [
            SELECT Id, Name, Process__r.Name, Step__c , Status__c, Message__c, IsDeleted
            FROM Message__c
            WHERE IsDeleted =  false
            ALL ROWS
        ];
        Integer actualCount = messages.size();
        
        //assert
        Integer expectedCount = 1;
        System.assertEquals(expectedCount, actualCount);
        
        String expectedProcessName = FailurePlugin.class.getName();
        System.assertEquals(expectedProcessName, messages[0].Process__r.Name);
        
        String expectedMessage = FailurePlugin.FailureMessage;
        System.assertEquals(expectedMessage, messages[0].Message__c);
    }

    static testMethod void callingBrokerStartSuccessfullyCallsStartImp() {
        //arrange processes
        Process__c markProcess = Processes.generateOne(Mark.class);
        Process__c terminateProcess = Processes.generateOne(Terminate.class);
        
        //arrange chain
        String  chainNameA = 'chainA';
        Chain__c chainA = new Chain__c(Name = chainNameA);
        insert chainA;
        
        //arrange steps
        Step__c stepA1 = Steps.generateOne(chainA.Id, markProcess.Id);
        Step__c stepA2 = Steps.generateOne(chainA.Id, terminateProcess.Id);
        Decimal sequenceA1 = stepA1.Sequence__c;
        Decimal sequenceA2 = stepA2.Sequence__c;
        
        //arrange specific broker implementation
        insert new BrokerSettings__c(BrokerClassName__c = BatchBroker.class.getName());
        
        //scenario:
        //resolved state, assume manual intervention to set status to 'Reprocess'
        Map<String,Object> parameters = new Map<String,Object> {
            'eda__chainName' => chainNameA,
            'eda__sequence' => 1, //not zero !!!
            'id' => '000000000000000AAA'
        };
        Message__c message = new Message__c(
            Step__c = stepA1.Id,
            Status__c = 'Reprocess',
            Parameters__c = Json.serializePretty(parameters)
        );
        insert message;
        
        //act
        Test.startTest();
        new BatchBroker().restartIfWorkPending();
        Test.stopTest();
        
        //assemble
        List<Message__c> messages = [
            SELECT id, Name, Process__r.Name, Step__c , Status__c, IsDeleted
            FROM Message__c
            WHERE IsDeleted =  false
            ALL ROWS
        ];
        
        //assert
        Integer expectedCount = 0;
        Integer actualCount = messages.size();
        System.assertEquals(expectedCount, actualCount);
    }
    
}