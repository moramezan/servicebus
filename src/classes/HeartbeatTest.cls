@IsTest private class HeartbeatTest {

    static testmethod void noInterestedProcessesReturnsZeroMessages() {
        //arrange parameters
        Boolean isHeartbeat = true;
        String stampAsString = '2014-01-18T12:00:00.000Z';
        Map<String,Object> parameters = new Map<String,Object>{
            'esb_IsHeartbeat' => isHeartbeat,
            'esb_EventStamp' => stampAsString 
        };

        //act
        Type reflector = Heartbeat.class;
        List<Map<String,Object>> parametersList = new Broker.Wrapper(reflector, parameters, null).invokeMain().Outputs;

        //assert
        Integer expectedSize = 0;
        Integer actualSize = parametersList.size();
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
        
        //arrange parameters
        Boolean isHeartbeat = true;
        String stampAsString = '2014-01-18T12:00:00.000Z';
        Map<String,Object> parameters = new Map<String,Object>{
            'esb_IsHeartbeat' => isHeartbeat,
            'esb_EventStamp' => stampAsString 
        };

        //act
        Type reflector = Heartbeat.class;
        List<Map<String,Object>> parametersList = new Broker.Wrapper(reflector, parameters, null).invokeMain().Outputs;

        //assert
        Integer expectedSize = 2;
        Integer actualSize = parametersList.size();
        System.assertEquals(expectedSize, actualSize);
    }  


    static testmethod void  HeartbeatParamEqToFalseOrMissingAlwaysReturnsZeroMessages() {
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
        
        //arrange parameters
        Boolean isHeartbeat = false;
        String stampAsString = '2014-01-18T12:00:00.000Z';
        Map<String,Object> parameters = new Map<String,Object>{
            'esb_IsHeartbeat' => isHeartbeat,
            'esb_EventStamp' => stampAsString 
        };

        //act
        Type reflector = Heartbeat.class;
        List<Map<String,Object>> parametersList = new Broker.Wrapper(reflector, parameters, null).invokeMain().Outputs;

        //assert
        Integer expectedSize = 0;
        Integer actualSize = parametersList.size();
        System.assertEquals(expectedSize, actualSize);
    }


    static testmethod void  ThrowsExceptionForInvalidStampParamAndHeartbeatParamEqToTrue() {
        //arrange parameters
        Boolean isHeartbeat = true;
        String stampAsString = 'XXXX-01-18T12:00:00.000Z';  // invalid stamp
        Map<String,Object> parameters = new Map<String,Object>{
            'esb_IsHeartbeat' => isHeartbeat,
            'esb_EventStamp' => stampAsString 
        };

        //assemble
        Boolean actualFlag = false;
        try {
            //act
            Type reflector = Heartbeat.class;
            List<Map<String,Object>> results = new Broker.Wrapper(reflector, parameters, null).invokeMain().Outputs;
        } catch (Heartbeat.HeartbeatException e) {
            actualFlag = true;
        }

        //assert
        Boolean expectedFlag = true;
        System.assertEquals(expectedFlag, actualFlag);
    }


    static testmethod void  DoesNotThrowExceptionForInvalidStampParamWhenHeartbeatParamEqToFalse() {
        //arrange parameters
        Boolean isHeartbeat = false;
        String stampAsString = 'XXXX-01-18T12:00:00.000Z';  // invalid stamp
        Map<String,Object> parameters = new Map<String,Object>{
            'esb_IsHeartbeat' => isHeartbeat,
            'esb_EventStamp' => stampAsString 
        };

        //assemble
        Boolean actualFlag = true;
        try {
            //act
            Type reflector = Heartbeat.class;
            List<Map<String,Object>> results = new Broker.Wrapper(reflector, parameters, null).invokeMain().Outputs;
        } catch (Heartbeat.HeartbeatException e) {
            actualFlag = false;
        }

        //assert
        Boolean expectedFlag = true;
        System.assertEquals(expectedFlag, actualFlag);
    }
}