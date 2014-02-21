public with sharing class FailurePlugin implements Process.Plugin {
 
    public static String FailureMessage = 'Fake Error Thrown in FailurePlugin';
    
    public class FailurePluginException extends Exception {}

    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult describeResult = new Process.PluginDescribeResult();
        describeResult.Name = 'FailurePlugin';
        describeResult.Description = 'A Process.Plugin that throws an exception for testing purposes. (Devoid of EDA inner class so will not be listed)';
        describeResult.Tag = 'Event Driven Architecture';
        return describeResult;
    }
    
    public Process.PluginResult invoke(Process.PluginRequest request) {
        Map<String,Object> parameters = request.inputParameters;
        throw new FailurePluginException(FailureMessage);
        return Utility.convert(new List<Map<String,Object>>{parameters});
    }
}