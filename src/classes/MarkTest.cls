@IsTest //-- no view of org data
private class MarkTest {

    static testmethod void hasTheCorrectAllowableInvocations() {
        //arrange 
        Type actualType = Mark.class;
        Type outerClass = Type.forName(actualType.getName());  
        Type innerClass = Type.forName(outerClass.getName() + '.' + 'Meta'); 
        ProcessObject.Meta meta = (ProcessObject.Meta)Json.deserialize(Json.serialize(innerClass.newInstance()), ProcessObject.Meta.class);
        
        //act 
        Integer actualAllowableInvocations = meta.AllowableInvocations;  

        //assemble
        actualAllowableInvocations = (actualAllowableInvocations == null) ? 1 : actualAllowableInvocations; 

        //assert
        Integer expectedAllowableInvocations = 1;
        System.assertEquals(expectedAllowableInvocations, actualAllowableInvocations);
    }
    
    
    static testmethod void callingExecuteReturnsExpectedParametersCollection() {
        // Arrange :
        String sequenceName = 'the-sequence';
        Decimal position = 1;
        String data = 'data';

        Map<String,Object> parameters = new Map<String,Object> {
            'esb_SequenceName' => sequenceName,
            'esb_Position' => position,
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
            actualMarkCount = (Decimal) actualParameters.get('esb_MarkCount' );
            actualGateGroupIdFlag = (actualParameters.get('esb_GateGroupId' ) != null);
        }
        Integer actualGateGroupSize = [SELECT COUNT() FROM GateGroup__c];

        // Assert
        System.assertEquals(expectedSize , actualSize );
        System.assertEquals(expectedGateGroupSize, actualGateGroupSize );
        System.assertEquals(expectedMarkCount, actualMarkCount);
        System.assertEquals(expectedGateGroupIdFlag, actualGateGroupIdFlag);
    }
}