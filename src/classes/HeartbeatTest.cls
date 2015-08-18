@IsTest private class HeartbeatTest {

    static testmethod void testHeartbeatDispatchesOneIndexedMessages() {
        //arrange process, sequence, step
        Sequence__c sequence = new Sequence__c(Name = 'Test');
        insert sequence;
        
        Step__c scheduleStep = SequenceModel.fromName(sequence.Name).appendStep(Schedule.class);
        
        //arrange input event
        Map<String,Object> inputEvent = new Map<String,Object>{
            'EntryPointTimestamp' => '2014-01-18T12:00:00.000Z'
        };
        
        //act
        ApexClassModel.BaseProcess process = new Heartbeat();
        
        //assemble
        List<Map<String,Object>> outputs = process.test(inputEvent);
        
        //assert
        Integer expectedSize = 1; //one schedule process
        Integer actualSize = outputs.size();
        System.assertEquals(expectedSize, actualSize, 'Should have one output.');
        
        //assemble
        Map<String,Object> output = outputs[0];
        
        //assert
        String expectedSequence = 'Test';
        String actualSequence = (String)output.get('Sequence');
        System.assertEquals(expectedSequence, actualSequence, 'Wrong sequence.');
    }

    static testmethod void noInterestedProcessesReturnsZeroMessages() {
        //arrange input event
        String stampAsString = '2014-01-18T12:00:00.000Z';
        Map<String,Object> inputEvent = new Map<String,Object>{
            'EntryPointTimestamp' => stampAsString
        };

        //act
        ApexClassModel.BaseProcess process = new Heartbeat();
        List<Map<String,Object>> outputEvents = process.test(inputEvent);

        //assert
        Integer expectedSize = 0;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize);
    }


    static testmethod void  gtOneInterestedProcessReturnsSameNumberOfMessages() {
        //arrange sequence
        Sequence__c interestedSequenceA = new Sequence__c(Name = 'InterestedSequenceA');
        insert interestedSequenceA;
        Sequence__c interestedSequenceB = new Sequence__c(Name = 'InterestedSequenceB');
        insert interestedSequenceB;

        //arrange steps
        Step__c stepA = SequenceModel.fromName(interestedSequenceA.Name).appendStep(Schedule.class);
        Step__c stepB = SequenceModel.fromName(interestedSequenceB.Name).appendStep(Schedule.class);
        
        //arrange events
        String stampAsString = '2014-01-18T12:00:00.000Z';
        Map<String,Object> inputEvent = new Map<String,Object>{
            'EntryPointTimestamp' => stampAsString
        };

        //act
        ApexClassModel.BaseProcess process = new Heartbeat();
        List<Map<String,Object>> outputEvents = process.test(inputEvent);

        //assert
        Integer expectedSize = 2;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize);
    }

}