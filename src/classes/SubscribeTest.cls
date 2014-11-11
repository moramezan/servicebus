@IsTest private class SubscribeTest{
    
    static testmethod void canDetermineConfigObject() {
        //arrange processes
        Process__c subscribeProcess = ProcessObject.generateOne(Subscribe.class);
        
        //act
        String actualConfiguration = subscribeProcess.ConfigObject__c;
        
        // Assert
        String expectedConfiguration = Schema.SobjectType.SubscribeConfiguration__c.Name;
        System.assertEquals(expectedConfiguration, actualConfiguration);
    }
    
    static testmethod void testSubscribeProcessActsAsNoop() {
        //arrange
        String data = '{"herp":"derp"}';
        Map<String,Object> parameters = (Map<String,Object>)System.Json.deserializeUntyped(data);
        
        //act
        List<Map<String,Object>> parametersList = Broker.invoke(Subscribe.class, parameters);
        
        //assert
        integer expectedSize = 1;
        integer actualSize = parametersList.size();
        System.assertEquals(expectedSize , actualSize);
        
        string expectedData = data;
        string actualData = system.json.serialize(parametersList[0]);
        System.assertEquals(expectedData, actualData);
    }
    
}