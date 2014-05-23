@isTest private class SubscribeTest{
    
    static testMethod void canDetermineConfigObject() {
        //arrange processes
        Process__c subscribeProcess = ProcessObject.generateOne(Subscribe.class);
        
        //act
        String actualConfiguration = subscribeProcess.ConfigObject__c;
        
        // Assert
        String expectedConfiguration = Schema.SobjectType.SubscribeConfiguration__c.Name;
        System.assertEquals(expectedConfiguration, actualConfiguration);
    }
    
    static testMethod void testSubscribeProcessActsAsNoop() {
        //arrange
        String data = '{"herp":"derp"}';
        Map<String,Object> parameters = (Map<String,Object>)System.Json.deserializeUntyped(data);
        Subscribe plugin = new Subscribe();
        
        //act
        Process.PluginResult result = plugin.invoke(new Process.PluginRequest(parameters));
        
        //assert
        List<Map<string, object>> parametersList = EdaUtility.convert(result);
        
        integer expectedSize = 1;
        integer actualSize = parametersList.size();
        System.assertEquals(expectedSize , actualSize);
        
        string expectedData = data;
        string actualData = system.json.serialize(parametersList[0]);
        System.assertEquals(expectedData, actualData);
    }
    
}