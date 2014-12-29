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
        Step__c stepA1 = StepObject.generateOne(sequenceA.Id, markProcess.Id);
        Step__c stepA2 = StepObject.generateOne(sequenceA.Id, terminateProcess.Id);
        Decimal positionA1 = stepA1.Position__c;
        Decimal positionA2 = stepA2.Position__c;
        
        //arrange specific broker implementation
        insert new BrokerSetting__c(BrokerClassName__c = SynchronousBroker.class.getName());
        
        //act 
        new Job(sequenceNameA, '000000000000000AAA').execute(null);
        
        //assemble
        List<Message__c> messages = [
            SELECT Id, Name, Status__c
            FROM Message__c
            WHERE Status__c != 'Completed'
        ];
        
        Integer actualCount = messages.size();
        
        //assert
        Integer expectedCount = 0;
        System.assertEquals(expectedCount , actualCount);
 
    }
    
}