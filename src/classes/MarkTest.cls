@IsTest //-- no view of org data
private class MarkTest {

    static testmethod void callingExecuteReturnsExpectedParametersCollection() {
        // Arrange :
        String sequenceName = 'the-sequence';
        Decimal position = 1;
        String data = 'data';

        Map<String,Object> parameters = new Map<String,Object> {
            'eda_SequenceName' => sequenceName,
            'eda_Position' => position,
            'data' => data
        };

        Decimal expectedSize = 1;
        Integer expectedGateGroupSize = 1;
        Decimal expectedMarkCount = 0;
        Boolean expectedGateGroupIdFlag = true;

        // Act
        List<Map<String,Object>> actualOutParametersList = Broker.invoke(Mark.class, parameters);

        // prepare
        Decimal actualSize = actualOutParametersList.size();
        Decimal actualMarkCount = null;
        Boolean actualGateGroupIdFlag = false;
        if (actualSize > 0) {
            Map<String,Object> actualParameters = actualOutParametersList[0];
            actualMarkCount = (Decimal) actualParameters.get('eda_MarkCount' );
            actualGateGroupIdFlag = (actualParameters.get('eda_GateGroupId' ) != null);
        }
        Integer actualGateGroupSize = [SELECT COUNT() FROM GateGroup__c];

        // Assert
        System.assertEquals(expectedSize , actualSize );
        System.assertEquals(expectedGateGroupSize, actualGateGroupSize );
        System.assertEquals(expectedMarkCount, actualMarkCount);
        System.assertEquals(expectedGateGroupIdFlag, actualGateGroupIdFlag);
    }
}