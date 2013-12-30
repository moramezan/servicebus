@isTest public class SubscribeTest{
	static testMethod void testDescribe() {
		// Arrange 
		
		// Act 
		Subscribe process = new Subscribe();
		Process.PluginDescribeResult result = process.describe();
		Map<string, Object> meta = Utility.meta(result.Description); 
			
		// Assert
		String expectedDescription = (String) meta.get('eda__configurable');
		String actualDescription = Schema.SobjectType.SubscribeConfiguration__c.Name;
		System.assertEquals(expectedDescription, actualDescription);
		
	}
	
	static testMethod void testSubscribeProcessActsAsNoop() {
		//arrange
		String data = '{"herp":"derp"}';
		Map<String,Object> notification = (Map<String,Object>)System.Json.deserializeUntyped(data);
		Subscribe process = new Subscribe();
		
		//act
		Process.PluginResult result = process.invoke(new Process.PluginRequest(notification));
		
		//assert
		List<Map<string, object>> notifications = Utility.convert(result);
		
		integer expectedSize = 1;
		integer actualSize = notifications.size();
		System.assertEquals(expectedSize , actualSize);
		
		string expectedData = data;
		string actualData = system.json.serialize( notifications [0] );
		System.assertEquals(expectedData, actualData);	
	}
}