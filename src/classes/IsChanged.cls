public class IsChanged implements Process.Plugin {
    
    public class Eda {
        public SObject configurable = IsChangedConfiguration__c.SObjectType.newSObject();
        public String icon = 'application_side_expand';
    }
    
    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult plugin = new Process.PluginDescribeResult();
        plugin.Name = 'IsChanged';
        plugin.Description = 'Detects if the value of a field has changed on an incoming SObject since the last time';
        plugin.Tag = 'Event Driven Architecture';
        return plugin;
    }
    
    public Process.PluginResult invoke(Process.PluginRequest pluginRequest) {
        Map<String,Object> notification = pluginRequest.inputParameters;
        List<Map<String,Object>> notifications = new List<Map<String,Object>>();
        
        IsChangedConfiguration__c configuration = [
            SELECT Id, LastHash__c, FieldName__c
            FROM IsChangedConfiguration__c
            WHERE Id = :(Id)notification.get('eda__configuration')
        ];
        
        Id objectId = (Id)notification.get('id');
        SObjectType objectType = objectId.getSObjectType();
        String objectName = objectType.getDescribe().getName();
        String fieldName = configuration.FieldName__c;
        
        String query = 'SELECT ' + fieldName + ' FROM ' + objectName + ' WHERE Id = :objectId';
        SObject obj = Database.query(query);
        
        Blob value = Blob.valueOf(String.valueOf(obj.get(fieldName)));
        String hash = EncodingUtil.convertToHex(Crypto.generateDigest('MD5', value));
        
        if (configuration.LastHash__c != hash) {
            //change detected
            notifications.add(notification);
        }
        
        configuration.LastHash__c = hash;
        update configuration;
        
        return Utility.convert(notifications);
    }
    

}