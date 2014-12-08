@IsTest private class SubscribeTest{

    static testmethod void hasTheCorrectAllowableInvocations() {
        //arrange 
        Type actualType = Subscribe.class;
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
    
    
    static testmethod void canDetermineStepConfig() {
        //arrange processes
        Process__c subscribeProcess = ProcessObject.generateOne(Subscribe.class);
        
        //act
        String actualConfig = subscribeProcess.StepConfig__c;
        
        // Assert
        String expectedConfig = Schema.SobjectType.SubscribeConfig__c.Name;
        System.assertEquals(expectedConfig, actualConfig);
    }
    
    static testmethod void testSubscribeProcessActsAsNoop() {
        //arrange
        String data = '{"herp":"derp"}';
        Map<String,Object> parameters = (Map<String,Object>)System.Json.deserializeUntyped(data);
        
        //act
        Type reflector = Subscribe.class;
        List<Map<String,Object>> parametersList = new Broker.Wrapper(reflector, parameters, null).invokeMain().Outputs;
        
        //assert
        integer expectedSize = 1;
        integer actualSize = parametersList.size();
        System.assertEquals(expectedSize , actualSize);
        
        string expectedData = data;
        string actualData = system.json.serialize(parametersList[0]);
        System.assertEquals(expectedData, actualData);
    }
    
}