public with sharing class Utility {
    
    static public Map<String,Object> meta(String description) {
        //no description at all
        if (null == description) return new Map<String,Object>();

        //no metadata on this process description
        if (!description.contains('{')) return new Map<String,Object>();
        
        //extract metadata and return map
        String json = '{' + description.substringBetween('{', '}') + '}';
        Map<String,Object> metadata = (Map<String,Object>)System.Json.deserializeUntyped(json);
        return metadata;
    }
    
    static public Map<String,String> convert(List<Process.PluginDescribeResult.InputParameter> inputs) {
        //populate list into key-value map
        Map<String,String> descriptions = new Map<String,String>();
        for (Process.PluginDescribeResult.InputParameter inputParameter : inputs) {
            descriptions.put(inputParameter.Name, inputParameter.Description);
        }
        return descriptions;
    }
    
    static public Process.PluginResult convert(List<Map<String,Object>> notifications) {
        Map<String,Object> results = new Map<String,Object>();
        
        Integer count = 0;
        for (Map<String,Object> notification : notifications) {
            results.put(String.valueOf(count++), notification);
        }
        
        return new Process.PluginResult(results);
    }
    
    static public List<Map<String,Object>> convert(Process.PluginResult results) {
        List<Map<String,Object>> notifications = new List<Map<String,Object>>();
        
        Integer count = 0;
        Integer size = results.outputParameters.size();
        
        for (Integer i = 0; i < size; i++) {
            Object result = results.outputParameters.get(String.valueOf(i));
            String data = System.Json.serialize(result);
            Map<String,Object> notification = (Map<String,Object>)System.Json.deserializeUntyped(data);
            notifications.add(notification);
        }
        
        return notifications;
    }
    
}