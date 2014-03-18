public class Debouncer implements Process.Plugin {
    
    public class DebouncerException extends Exception {}
    
    public class Meta {
        public SObject ConfigObject = DebouncerConfiguration__c.SObjectType.newSobject();
        public String Icon = 'key_go';
    }
    
    public Process.PluginDescribeResult describe() {
        Process.PluginDescribeResult result = new Process.PluginDescribeResult();
        result.Tag = 'Event Driven Architecture';
        result.Name = 'Debouncer';
        result.Description = 'Swallows message unless the time elapsed since receiving a prior notification with the same key exceeds a min threshold';
        return result;
    }
    
    public Process.PluginResult invoke(Process.PluginRequest pluginRequest) {
        Map<String,Object> parameters = pluginRequest.inputParameters;
        List<Map<String,Object>> parametersList = new List<Map<String,Object>>();
        
        String key = (String) parameters.get('Id'); //Note we sill treat null as a unique key with value [null]
        Id configurationId = (Id)parameters.get('eda_ConfigObjectId');
        
        if (configurationId == null) {
            throw new DebouncerException('Cannot invoke debouncer with null parameters[eda_configuration]');
        }
        
        // retrieve minimum time between releases
        DebouncerConfiguration__c configuration = [
        SELECT Id, MinimumHoursBetween__c
            FROM DebouncerConfiguration__c
            WHERE Id = :configurationId
        ];
        Integer minimumHours = (configuration.MinimumHoursBetween__c == null) ? 0 : (Integer)configuration.MinimumHoursBetween__c;
        
        // retrieve debouncer (if any)
        List<Debouncer__c> debouncers = [
            SELECT Id, LastFiredDate__c, Key__c
            FROM Debouncer__c
            WHERE DebouncerConfiguration__c = :configurationId
            AND Key__c = :key
        ];
        
        DateTime currentStamp = System.now();
        Boolean release = debounce( currentStamp, key, minimumHours, debouncers , configurationId );
        if (release) {
            parametersList.add(parameters);
        }

        // housekeeping
        Integer twentyFourHours = 24;
        deleteOldDebouncers(currentStamp, minimumHours, twentyFourHours) ;
        
        return EdaUtility.convert(parametersList);
    }
    
    @testVisible
    private static Boolean debounce(
        DateTime currentStamp,
        String key,
        Integer minimumHours,
        List<Debouncer__c> debouncers,
        Id debouncerConfigurationId
    ) {
        // normalize
        Debouncer__c debouncer;
        Boolean keyInstance = (debouncers.size() > 0);
        if (!keyInstance) {
            debouncer = new Debouncer__c (
                DebouncerConfiguration__c = debouncerConfigurationId,
                LastFiredDate__c = null,
                Key__c = key
            );
            insert debouncer;
        } else {
            debouncer = debouncers[0];
        }
    
    
        // decision and potential release
        Boolean release = ( ! keyInstance );
        if (!release) {
            DateTime cutOff = currentStamp.addHours(-1 * minimumHours);
            release = debouncers[0].LastFiredDate__c < cutOff;
        }
        
        // persist state
        if (release) {
            debouncer.LastFiredDate__c = currentStamp;
            update debouncer;
        }
        
        return release;
    }
    
    
    
    @testVisible
    private static void deleteOldDebouncers(
        DateTime currentStamp,
        Integer minimumHours,
        Integer bufferHours
    ) {
    
        DateTime staleStamp = currentStamp.AddHours( -1 * ( bufferHours + minimumHours) ) ;
        List<Id> ids = new List<Id> (
        new Map<Id, Debouncer__c>([
            SELECT Id
            FROM Debouncer__c
            WHERE LastFiredDate__c < :staleStamp
        ]).keySet());
        
        if (ids.size() > 0) {
            Database.delete(ids);
            Database.emptyRecycleBin(ids);
        }
    }
}