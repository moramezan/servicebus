@IsTest private class SubscribeTest{

    static testmethod void hasTheCorrectLimits() {
        //arrange 
        Type actualType = Subscribe.class;
        Type outerClass = Type.forName(actualType.getName());  
        Type innerClass = Type.forName(outerClass.getName() + '.' + 'ESB'); 
        ProcessObject.ESB meta = (ProcessObject.ESB)Json.deserialize(Json.serialize(innerClass.newInstance()), ProcessObject.ESB.class);
        
        //act 
        Integer actualLimits = meta.Limits;  

        //assemble
        actualLimits = (actualLimits == null) ? 1 : actualLimits; 

        //assert
        Integer expectedLimits = 90;
        System.assertEquals(expectedLimits, actualLimits);
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