@isTest private class EdaUtilityTest {
    static testMethod void testInputs2map() {
        //arrange
        List<Process.PluginDescribeResult.InputParameter> inputs = new List<Process.PluginDescribeResult.InputParameter>{
            new Process.PluginDescribeResult.InputParameter(
                'one',
                'herp',
                Process.PluginDescribeResult.ParameterType.String,
                false
            ),
            new Process.PluginDescribeResult.InputParameter(
                'two',
                'derp',
                Process.PluginDescribeResult.ParameterType.String,
                false
            )
        };
        
        //act
        Map<String,String> descriptions = EdaUtility.convert(inputs);
        System.assertEquals('herp', descriptions.get('one'));
        System.assertEquals('derp', descriptions.get('two'));
    }
    
    static testMethod void testParametersList2result() {
        //arrange
        String data = '[{"aaa":"1", "bbb":"foo"}, {"ccc":"2", "ddd":"bar"}]';
        List<Map<String,String>> parametersList = (List<Map<String,String>>)System.Json.deserialize(data, List<Map<String,String>>.class);
        
        //act
        Map<String,Object> results = EdaUtility.convert(parametersList).outputParameters;
        
        //assert
        String expectedOne = System.Json.serialize(new Map<String,Object>{'aaa' => '1', 'bbb' => 'foo'});
        System.assertEquals(expectedOne, System.Json.serialize(results.get('0')));
        
        String expectedTwo = System.Json.serialize(new Map<String,Object>{'ccc' => '2', 'ddd' => 'bar'});
        System.assertEquals(expectedTwo, System.Json.serialize(results.get('1')));
    }
    
    static testMethod void testResult2ParametersList() {
        //arrange
        Process.PluginResult result = new Process.PluginResult(new Map<String,Object>{
            '0' => new Map<String,Object>{'aaa' => '1', 'bbb' => 'foo'},
            '1' => new Map<String,Object>{'ccc' => '2', 'ddd' => 'bar'}
        });
        
        //act
        List<Map<String,Object>> parametersList = EdaUtility.convert(result);
        System.debug(parametersList);
        
        //assert
        for (Map<String,Object> parameters : parametersList) {
            String data = System.Json.serialize(parameters);
            if (data.startsWith('{"aaa"')) {
                String expectedOne = '{"aaa":"1","bbb":"foo"}';
                System.assertEquals(expectedOne, System.Json.serialize(parameters));
            }
            
            if (data.startsWith('{"ccc"')) {
                String expectedOne = '{"ccc":"2","ddd":"bar"}';
                System.assertEquals(expectedOne, System.Json.serialize(parameters));
            }
        }
    }
}