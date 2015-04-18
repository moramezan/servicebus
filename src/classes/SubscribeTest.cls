@IsTest private class SubscribeTest{

    static testmethod void hasTheCorrectLimits() {
        //assert
        Integer expectedLimits = 5000;
        Integer actualLimits = new Subscribe.ESB().Limits;
        System.assertEquals(expectedLimits, actualLimits);
    }
    
    
    static testmethod void testSubscribeProcessActsAsNoop() {
        //arrange
        String data = '{"herp":"derp"}';
        Map<String,Object> parameters = (Map<String,Object>)System.Json.deserializeUntyped(data);
        
        //act
        ProcessModel.BaseProcess process = new Subscribe();
        List<Map<String,Object>> parametersList = process.execute(parameters);
        
        //assert
        integer expectedSize = 1;
        integer actualSize = parametersList.size();
        System.assertEquals(expectedSize , actualSize);
        
        string expectedData = data;
        string actualData = system.json.serialize(parametersList[0]);
        System.assertEquals(expectedData, actualData);
    }
    
}