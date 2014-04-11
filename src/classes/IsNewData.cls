public class IsNewData implements Process.Plugin {
 
    public class IsNewDataException extends Exception {}
    
    public class Meta {
        public SObject ConfigObject = IsNewDataConfiguration__c.SObjectType.newSobject();
        public String Icon = 'key_go';
        public String DocsPageUrl = Url.getSalesforceBaseUrl().toExternalForm() + Page.IsNewDataHelp.getUrl();
    }
    
    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult result = new Process.PluginDescribeResult();
        result.Tag = 'Sample Processes';
        result.Name = 'IsNewData';
        result.Description = 'Detects if a certain time has elapsed since receiving a message with the same data';
        return result;
    }
    
    public Process.PluginResult invoke(Process.PluginRequest pluginRequest) {
        Map<String,Object> parameters = pluginRequest.inputParameters;
        List<Map<String,Object>> parametersList = new List<Map<String,Object>>();
        
        String key = (String) parameters.get('Id'); //Note we sill treat null as a unique key with value [null]
        Id configurationId = (Id)parameters.get('eda_ConfigObjectId');
        
        if (configurationId == null) {
            throw new IsNewDataException('Cannot invoke IsNewData with null parameters[eda_ConfigObjectId]');
        }
        
        // retrieve minimum time between releases
        IsNewDataConfiguration__c configuration = (IsNewDataConfiguration__c)SalesforceObject.getById(configurationId);
        Integer minimumHours = (configuration.MinimumHoursBetween__c == null) ? 0 : (Integer)configuration.MinimumHoursBetween__c;
        
        // retrieve IsNewData (if any)
        List<IsNewDataInstance__c> IsNewDatas = [
            SELECT Id, LastFiredDate__c, Key__c
            FROM IsNewDataInstance__c
            WHERE IsNewDataConfiguration__c = :configurationId
            AND Key__c = :key
        ];
        
        DateTime currentStamp = System.now();
        Boolean release = debounce( currentStamp, key, minimumHours, IsNewDatas , configurationId );
        if (release) {
            parametersList.add(parameters);
        }

        // housekeeping
        Integer twentyFourHours = 24;
        deleteOldIsNewDatas(currentStamp, minimumHours, twentyFourHours) ;
        
        return EdaUtility.convert(parametersList);
    }
    
    @testVisible
    private static Boolean debounce(
        DateTime currentStamp,
        String key,
        Integer minimumHours,
        List<IsNewDataInstance__c> IsNewDatas,
        Id IsNewDataConfigurationId
    ) {
        // normalize
        IsNewDataInstance__c IsNewData;
        Boolean keyInstance = (IsNewDatas.size() > 0);
        if (!keyInstance) {
            IsNewData = new IsNewDataInstance__c (
                IsNewDataConfiguration__c = IsNewDataConfigurationId,
                LastFiredDate__c = null,
                Key__c = key
            );
            insert IsNewData;
        } else {
            IsNewData = IsNewDatas[0];
        }
    
    
        // decision and potential release
        Boolean release = ( ! keyInstance );
        if (!release) {
            DateTime cutOff = currentStamp.addHours(-1 * minimumHours);
            release = IsNewDatas[0].LastFiredDate__c < cutOff;
        }
        
        // persist state
        if (release) {
            IsNewData.LastFiredDate__c = currentStamp;
            update IsNewData;
        }
        
        return release;
    }
    
    
    
    @testVisible
    private static void deleteOldIsNewDatas(
        DateTime currentStamp,
        Integer minimumHours,
        Integer bufferHours
    ) {
    
        DateTime staleStamp = currentStamp.AddHours( -1 * ( bufferHours + minimumHours) ) ;
        List<Id> ids = new List<Id> (
        new Map<Id, IsNewDataInstance__c>([
            SELECT Id
            FROM IsNewDataInstance__c
            WHERE LastFiredDate__c < :staleStamp
        ]).keySet());
        
        if (ids.size() > 0) {
            Database.delete(ids);
            Database.emptyRecycleBin(ids);
        }
    }
}