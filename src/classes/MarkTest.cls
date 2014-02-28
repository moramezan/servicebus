@isTest //-- no view of org data
private class MarkTest {

    static testMethod void testProcessIsDescribed() {
        Mark mark = new Mark();
        System.assertNotEquals(null, mark.describe().Name);
        System.assertNotEquals(null, mark.describe().Description);
        System.assertNotEquals(null, mark.describe().Tag);
    }
    
    static testMethod void callingExecuteReturnsExpectedParametersCollectio() {
        // Arrange :
        String sequenceName = 'the-sequence';
        Decimal position = 1;
        String data = 'data';

        Map<String,Object> parameters = new Map<String,Object> {
            'eda_sequenceName' => sequenceName,
            'eda_position' => position,
            'data' => data
        };

        Decimal expectedSize = 1;
        Integer expectedGateGroupSize = 1;
        Decimal expectedMarkCount = 0;
        Boolean expectedGateGroupIdFlag = true;

        // Act
        Mark mark = new Mark();
        Process.PluginResult results = mark.invoke(new Process.PluginRequest(parameters));
        List<Map<String,Object>> actualOutParametersList = EdaUtility.convert(results);

        // prepare
        Decimal actualSize = actualOutParametersList.size();
        Decimal actualMarkCount = null;
        Boolean actualGateGroupIdFlag = false;
        if (actualSize > 0) {
            Map<String,Object> actualParameters = actualOutParametersList[0];
            actualMarkCount = (Decimal) parameters.get('eda_markCount' );
            actualGateGroupIdFlag = (parameters.get('eda_gateGroupId' ) != null);
        }
        integer actualGateGroupSize = [SELECT Id FROM GateGroup__C].size();

        // Assert
        System.assertEquals(expectedSize , actualSize );
        System.assertEquals(expectedGateGroupSize, actualGateGroupSize );
        System.assertEquals(expectedMarkCount, actualMarkCount);
        System.assertEquals(expectedGateGroupIdFlag, actualGateGroupIdFlag);
    }
}