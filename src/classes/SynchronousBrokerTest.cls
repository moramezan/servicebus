@IsTest private class SynchronousBrokerTest{

    private static testmethod void callingEnqueueSuccessfullyExecutesStepsInSequence() {
        //arrange processes
        Process__c markProcess = ProcessObject.generateOne(Mark.class);
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        
        //arrange sequence
        String sequenceNameA = 'sequenceA';
        Sequence__c sequenceA = new Sequence__c(Name = sequenceNameA);
        insert sequenceA;
        
        //arrange steps
        Step__c stepA1 = StepObjectSet.generateOne(sequenceA.Id, markProcess.Id);
        Step__c stepA2 = StepObjectSet.generateOne(sequenceA.Id, terminateProcess.Id);
        Decimal positionA1 = stepA1.Position__c;
        Decimal positionA2 = stepA2.Position__c;
        
        //arrange specific broker implementation
        insert new BrokerSettings__c(BrokerClassName__c = SynchronousBroker.class.getName());
        
        //act 
        Broker.enqueue(sequenceNameA, '000000000000000AAA');
        
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
    
}