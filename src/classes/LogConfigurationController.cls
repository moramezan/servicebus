public class LogConfigurationController {
    
    private ApexPages.StandardController controller;
    
    public LogConfigurationController(ApexPages.StandardController controller) {
        this.controller = controller;
    }
    
    public System.PageReference LogGroupView() {
        LogConfiguration__c logConfiguration = (LogConfiguration__c)this.controller.getRecord();
        return getLogGroupPageReference( logConfiguration.Id );
    }
    
    
    /**
     * Produce the related list of  LogGroups for a given LogConfiguration Id
     * The custom URL takes the following format
     * https://<sf-pod>/<list-prefix>?rlid=<the-lookup-field-id>&id=<the-given-parent-Id>
     * where 
     *   <sf-pod> =  salesforce-pod (eg eu2.salesforce.com )
     *   <list-prefix> = 3 character prefix of the LogGroup list
     *   <the-lookup-field-id> = the 15 character field id of the field that lookups up to the parent LogConfiguration - it's derived via the tooling api
     *   <the-given-parent-Id> = the 18 character LogConfiguration Id whose child LogGroup records we are interested in
     * 
     * tooling api
     * resolve Id of LogGroup
     * resolve Id of field on LogGroup that looks up to the parent LogConfiguration;
     * 
     */ 
    @TestVisible
    private static System.PageReference getLogGroupPageReference(Id logConfigurationId ) {
        Schema.describesobjectresult logGroupDescribe = LogGroup__c.SObjectType.getDescribe(); // magic string compile binding 
        Schema.describesobjectresult logConfigurationDescribe = LogConfiguration__c.SObjectType.getDescribe(); // magic string compile binding    
        String logGroupObjectName = logGroupDescribe.getName().replaceAll('__c','');  
        String logConfigurationLookupFieldName = logConfigurationDescribe.getName().replaceAll('__c','');      
        String logGroupKeyPrefix  = logGroupDescribe.getKeyPrefix();   
        
        
        String lkid = '000000000000000';
        if (!Test.isRunningTest()) {
            Api.Client client = new Api.Client();
            Api.QueryResult customObjects = client.query('SELECT Id FROM CustomObject WHERE DeveloperName = \'' + logGroupObjectName + '\'');
            Id logGroupObjectId = customObjects.records[0].Id;
            Api.QueryResult customFields = client.query('SELECT Id FROM CustomField WHERE DeveloperName = \'' + logConfigurationLookupFieldName + '\' AND TableEnumOrId = \'' + logGroupObjectId + '\'');
            lkid = customFields.records[0].Id.left(15);
        }
        
        return new PageReference( '/' + logGroupKeyPrefix + '?rlid=' + lkid + '&id=' + logConfigurationId );
    }
}