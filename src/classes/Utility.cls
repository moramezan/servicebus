public with sharing class Utility {

    static public Map<String,String> convert(List<Process.PluginDescribeResult.InputParameter> inputs) {
        //populate list into key-value map
        Map<String,String> descriptions = new Map<String,String>();
        for (Process.PluginDescribeResult.InputParameter inputParameter : inputs) {
            descriptions.put(inputParameter.Name, inputParameter.Description);
        }
        return descriptions;
    }
    
    static public Process.PluginResult convert(List<Map<String,Object>> parametersList) {
        Map<String,Object> results = new Map<String,Object>();
        
        Integer count = 0;
        for (Map<String,Object> parameters : parametersList) {
            results.put(String.valueOf(count++), parameters);
        }
        
        return new Process.PluginResult(results);
    }
    
    static public List<Map<String,Object>> convert(Process.PluginResult results) {
        List<Map<String,Object>> parametersList = new List<Map<String,Object>>();
        
        Integer count = 0;
        Integer size = results.outputParameters.size();
        
        for (Integer i = 0; i < size; i++) {
            Object result = results.outputParameters.get(String.valueOf(i));
            String data = System.Json.serialize(result);
            Map<String,Object> parameters = (Map<String,Object>)System.Json.deserializeUntyped(data);
            parametersList.add(parameters);
        }
        
        return parametersList;
    }
    
}