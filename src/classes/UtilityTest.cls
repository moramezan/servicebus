@isTest public class UtilityTest {
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
        Map<String,String> descriptions = Utility.convert(inputs);
        System.assertEquals('herp', descriptions.get('one'));
        System.assertEquals('derp', descriptions.get('two'));
    }
    
    static testMethod void testNotifications2result() {
        //arrange
        String data = '[{"aaa":"1", "bbb":"foo"}, {"ccc":"2", "ddd":"bar"}]';
        List<Map<String,String>> notifications = (List<Map<String,String>>)System.Json.deserialize(data, List<Map<String,String>>.class);
        
        //act
        Map<String,Object> results = Utility.convert(notifications).outputParameters;
        
        //assert
        String expectedOne = System.Json.serialize(new Map<String,Object>{'aaa' => '1', 'bbb' => 'foo'});
        System.assertEquals(expectedOne, System.Json.serialize(results.get('0')));
        
        String expectedTwo = System.Json.serialize(new Map<String,Object>{'ccc' => '2', 'ddd' => 'bar'});
        System.assertEquals(expectedTwo, System.Json.serialize(results.get('1')));
    }
    
    static testMethod void testResult2Notification() {
        //arrange
        Process.PluginResult result = new Process.PluginResult(new Map<String,Object>{
            '0' => new Map<String,Object>{'aaa' => '1', 'bbb' => 'foo'},
            '1' => new Map<String,Object>{'ccc' => '2', 'ddd' => 'bar'}
        });
        
        //act
        List<Map<String,Object>> notifications = Utility.convert(result);
        System.debug(notifications);
        
        //assert
        for (Map<String,Object> notification : notifications) {
            String data = System.Json.serialize(notification);
            if (data.startsWith('{"aaa"')) {
                String expectedOne = '{"aaa":"1","bbb":"foo"}';
                System.assertEquals(expectedOne, System.Json.serialize(notification));
            }
            
            if (data.startsWith('{"ccc"')) {
                String expectedOne = '{"ccc":"2","ddd":"bar"}';
                System.assertEquals(expectedOne, System.Json.serialize(notification));
            }
        }
    }
}