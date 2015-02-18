@IsTest public class DisperseTest {
    
    static testmethod void testDisperseSendsMultipleMessages() {
        //arrange processes
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        
        //arrange sequences
        Sequence__c sequence1 = new Sequence__c(Name = 'Test1');
        insert sequence1;
        Step__c step1 = StepObject.generateOne(sequence1.Id, terminateProcess.Id);
        
        Sequence__c sequence2 = new Sequence__c(Name = 'Test2');
        insert sequence2;
        Step__c step2 = StepObject.generateOne(sequence2.Id, terminateProcess.Id);
        
        Sequence__c sequence3 = new Sequence__c(Name = 'Test3');
        insert sequence3;
        Step__c step3 = StepObject.generateOne(sequence3.Id, terminateProcess.Id);
        
        //arrange disperser
        DisperseConfig__c config = new DisperseConfig__c();
        insert config;
        insert new DisperseDestination__c(DisperseConfig__c = config.Id, Sequence__c = sequence1.Id);
        insert new DisperseDestination__c(DisperseConfig__c = config.Id, Sequence__c = sequence2.Id);
        insert new DisperseDestination__c(DisperseConfig__c = config.Id, Sequence__c = sequence3.Id);
        
        //arrange invocation
        Disperse process = new Disperse();
        process.StepConfig = config;
        process.Event = '{}';
        
        //act
        String outputs = process.toString();
        
        //assemble
        List<Object> events = (List<Object>)Json.deserializeUntyped(outputs);
        
        //assert
        Integer expectedOutputs = 3;
        Integer actualOutputs = events.size();
        System.assertEquals(expectedOutputs, actualOutputs, 'Wrong number of outputs.');
    }
    
    static testmethod void testDisperseDumbConfig() {
        //arrange processes
        Process__c terminateProcess = ProcessObject.generateOne(Terminate.class);
        
        //arrange sequences
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        Step__c step1 = StepObject.generateOne(sequence.Id, terminateProcess.Id);
        
        //arrange disperser
        DisperseConfig__c config = new DisperseConfig__c();
        insert config;
        insert new DisperseDestination__c(DisperseConfig__c = config.Id, Sequence__c = sequence.Id);
        
        //arrange invocation
        Disperse process = new Disperse();
        process.StepConfig = config;
        process.Event = '{"__SequenceName":"Test"}';
        
        //act
        try {
            String outputs = process.toString();
            System.assert(false, '');
        } catch (Disperse.DisperseException e) {
            String expectedMessage = 'Disperse cannot include its own Sequence as a Destination.';
            String actualMessage = e.getMessage();
            System.assertEquals(expectedMessage, actualMessage, 'Wrong exception.');
        }
    }
    
}