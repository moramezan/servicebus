@IsTest public class DisperseTest {
    
    static testmethod void testDisperseSendsMultipleMessages() {
        //arrange sequences
        Sequence__c sequence1 = new Sequence__c(Name = 'Test1');
        insert sequence1;
        Step__c step1 = SequenceModel.fromName(sequence1.Name).appendStep(Terminate.class.getName());
        
        Sequence__c sequence2 = new Sequence__c(Name = 'Test2');
        insert sequence2;
        Step__c step2 = SequenceModel.fromName(sequence2.Name).appendStep(Terminate.class.getName());
        
        Sequence__c sequence3 = new Sequence__c(Name = 'Test3');
        insert sequence3;
        Step__c step3 = SequenceModel.fromName(sequence3.Name).appendStep(Terminate.class.getName());
        
        //arrange disperser
        DisperseConfig__c config = new DisperseConfig__c();
        insert config;
        insert new DisperseDestination__c(DisperseConfig__c = config.Id, Sequence__c = sequence1.Id);
        insert new DisperseDestination__c(DisperseConfig__c = config.Id, Sequence__c = sequence2.Id);
        insert new DisperseDestination__c(DisperseConfig__c = config.Id, Sequence__c = sequence3.Id);
        
        //arrange invocation
        Disperse process = new Disperse();
        process.Event = Json.serialize(new Map<String,Object>{
            'esb__StepConfig' => config
        });
        
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
        //arrange sequences
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        Step__c step1 = SequenceModel.fromName(sequence.Name).appendStep(Terminate.class.getName());
        
        //arrange disperser
        DisperseConfig__c config = new DisperseConfig__c();
        insert config;
        insert new DisperseDestination__c(DisperseConfig__c = config.Id, Sequence__c = sequence.Id);
        
        //arrange invocation
        Disperse process = new Disperse();
        process.Event = Json.serialize(new Map<String,Object>{
            'esb__StepConfig' => config,
            '__SequenceName' => 'Test'
        });
        
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