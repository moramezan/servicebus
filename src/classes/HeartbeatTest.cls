@IsTest private class HeartbeatTest {

    static testmethod void testHeartbeatDispatchesOneIndexedMessages() {
        //arrange process, sequence, step
        Process__c scheduleProcess = ProcessObject.generateOne(Schedule.class);
        
        Sequence__c sequence = new Sequence__c(Name = 'test');
        insert sequence;
        
        Step__c scheduleStep = StepObject.generateOne(sequence.Id, scheduleProcess.Id);
        
        //arrange input event
        String inputEvent = '{"esb__EntryPointDatetime":"2014-01-18T12:00:00.000Z"}';
        
        //act
        Heartbeat process = new Heartbeat();
        process.Event = inputEvent;
        String data = process.toString();
        
        //assemble
        List<Object> outputs = (List<Object>)Json.deserializeUntyped(data);
        
        //assert
        Integer expectedSize = 1; //one schedule process
        Integer actualSize = outputs.size();
        System.assertEquals(expectedSize, actualSize, 'Should have one output.');
        
        //assemble
        Map<String,Object> output = (Map<String,Object>)outputs[0];
        
        //assert
        Integer expectedPosition = 1;
        Integer actualPosition = (Integer)output.get('__Position');
        System.assertEquals(expectedPosition, actualPosition, 'Position should be 1.');
    }

    static testmethod void noInterestedProcessesReturnsZeroMessages() {
        //arrange input event
        String stampAsString = '2014-01-18T12:00:00.000Z';
        Map<String,Object> inputEvent = new Map<String,Object>{
            'esb__EntryPointDatetime' => stampAsString 
        };

        //act
        Type reflector = Heartbeat.class;
        List<Map<String,Object>> outputEvents = new Broker.Wrapper(reflector, inputEvent, null).invokeMain().Outputs;

        //assert
        Integer expectedSize = 0;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize);
    } 


    static testmethod void  gtOneInterestedProcessReturnsSameNumberOfMessages() {
        //arrange processes
        Process__c ScheduleProcess = ProcessObject.generateOne(Schedule.class);

        //arrange sequence
        Sequence__c interestedSequenceA = new Sequence__c(Name = 'InterestedSequenceA');
        insert interestedSequenceA;
        Sequence__c interestedSequenceB = new Sequence__c(Name = 'InterestedSequenceB');
        insert interestedSequenceB;

        //arrange steps
        Step__c stepA = StepObject.generateOne(interestedSequenceA.Id, ScheduleProcess.Id);
        Step__c stepB = StepObject.generateOne(interestedSequenceB.Id, ScheduleProcess.Id);
        
        //arrange events
        String stampAsString = '2014-01-18T12:00:00.000Z';
        Map<String,Object> inputEvent = new Map<String,Object>{
            'esb__EntryPointDatetime' => stampAsString 
        };

        //act
        Type reflector = Heartbeat.class;
        List<Map<String,Object>> outputEvents = new Broker.Wrapper(reflector, inputEvent, null).invokeMain().Outputs;

        //assert
        Integer expectedSize = 2;
        Integer actualSize = outputEvents.size();
        System.assertEquals(expectedSize, actualSize);
    }  

    static testmethod void  ThrowsExceptionForInvalidStampParamAndHeartbeatParamEqToTrue() {
        //arrange inputEvent
        String stampAsString = 'XXXX-01-18T12:00:00.000Z';  // invalid stamp
        Map<String,Object> inputEvent = new Map<String,Object>{
            'esb__EntryPointDatetime' => stampAsString 
        };

        //assemble
        Boolean actualFlag = false;
        try {
            //act
            Type reflector = Heartbeat.class;
            List<Map<String,Object>> results = new Broker.Wrapper(reflector, inputEvent, null).invokeMain().Outputs;
        } catch (Heartbeat.HeartbeatException e) {
            actualFlag = true;
        }

        //assert
        Boolean expectedFlag = true;
        System.assertEquals(expectedFlag, actualFlag);
    }

}