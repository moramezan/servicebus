@IsTest //-- no view of org data
private class MarkTest {

    static testmethod void hasTheCorrectLimits() {
        //assert
        Integer expectedLimits = 75;
        Integer actualLimits = new Mark.ESB().Limits;
        System.assertEquals(expectedLimits, actualLimits);
    }
    
    
    static testmethod void callingExecuteReturnsExpectedParametersCollection() {
        // Arrange :
        String sequenceName = 'the-sequence';
        Decimal position = 1;
        String data = 'data';

        Map<String,Object> parameters = new Map<String,Object> {
            '__SequenceName' => sequenceName,
            '__Position' => position,
            'data' => data
        };

        Decimal expectedSize = 1;
        Integer expectedGateGroupSize = 1;
        Decimal expectedMarkCount = 0;
        Boolean expectedGateGroupIdFlag = true;

        // Act
        Type reflector = Mark.class;
        List<Map<String,Object>> actualOutParametersList = new Broker.Wrapper(reflector, parameters, null).invokeMain().Outputs;

        // prepare
        Decimal actualSize = actualOutParametersList.size();
        Decimal actualMarkCount = null;
        Boolean actualGateGroupIdFlag = false;
        if (actualSize > 0) {
            Map<String,Object> actualParameters = actualOutParametersList[0];
            actualMarkCount = (Decimal) actualParameters.get('__MarkCount' );
            actualGateGroupIdFlag = (actualParameters.get('esb__GateGroupId' ) != null);
        }
        Integer actualGateGroupSize = [SELECT COUNT() FROM GateGroup__c];

        // Assert
        System.assertEquals(expectedSize , actualSize );
        System.assertEquals(expectedGateGroupSize, actualGateGroupSize );
        System.assertEquals(expectedMarkCount, actualMarkCount);
        System.assertEquals(expectedGateGroupIdFlag, actualGateGroupIdFlag);
    }
}