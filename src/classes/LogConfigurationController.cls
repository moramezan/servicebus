public class LogConfigurationController {
    
    private ApexPages.StandardController controller;
    
    public LogConfigurationController(ApexPages.StandardController controller) {
        this.controller = controller;
    }
    
    public System.PageReference LogGroupView() {
        LogConfiguration__c logConfiguration = (LogConfiguration__c)this.controller.getRecord();
        return getLogGroupPageReference( logConfiguration.Id );
    }
    
    public class IdentityResult {
        public String id;
        public String asserted_user;
        public String user_id;
        public String organization_id;
        public String username;
        public String nick_name;
        public String display_name;
        public String email;
        public String first_name;
        public String last_name;
        //public Map<String,Object> status;
        public Map<String,String> photos;
        public Map<String,String> urls;
        public Boolean active;
        public String user_type;
        public String language;
        public String locale;
        public Integer utcOffset;
        public DateTime last_modified_date;
    }
    
    /**
     * eg "https://pod.salesforce.com"
     */
    @TestVisible static private String podProtocolAndHost() {
        String orgId = UserInfo.getOrganizationId();
        String userId = UserInfo.getUserId();
        
        System.PageReference pr = new System.PageReference('/id/' + orgId + '/' + userId);
        pr.getParameters().put('oauth_token', UserInfo.getSessionId());
        pr.getParameters().put('format', 'json');
        
        String data;
        if (!Test.isRunningTest()) {
            //fetch real identity
            data = pr.getContent().toString();
        } else {
            //fake test identity
            data = '{"urls": {"rest": "' + Url.getSalesforceBaseUrl().toExternalForm() + '"}}';
        }
        IdentityResult result = (IdentityResult)Json.deserialize(data, IdentityResult.class);
        
        Url rest = new Url(result.urls.get('rest'));
        String protocolAndHost = rest.getProtocol() + '://' + rest.getHost();
        return protocolAndHost;
    }
    
    /**
     * Produce the related list of  LogGroups for a given LogConfiguration Id
     * The custom URL takes the following format
     * https://<sf-pod>/<list-prefix>?rlid=<the-lookup-field-id>&id=<the-given-parent-Id>
     * where
     *   <sf-pod> =  salesforce-pod (eg pod.salesforce.com )
     *   <list-prefix> = 3 character prefix of the LogGroup list
     *   <the-lookup-field-id> = the 15 character field id of the field that lookups up to the parent LogConfiguration - it's derived via the tooling api
     *   <the-given-parent-Id> = the 18 character LogConfiguration Id whose child LogGroup records we are interested in
     *
     * tooling api
     * resolve Id of LogGroup
     * resolve Id of field on LogGroup that looks up to the parent LogConfiguration;
     *
     */
    @TestVisible static private System.PageReference getLogGroupPageReference(Id logConfigurationId ) {
        Schema.describesobjectresult logGroupDescribe = LogGroup__c.SObjectType.getDescribe(); // magic string compile binding
        Schema.describesobjectresult logConfigurationDescribe = LogConfiguration__c.SObjectType.getDescribe(); // magic string compile binding
        String logGroupObjectName = logGroupDescribe.getName().replaceAll('__c','');
        String logConfigurationLookupFieldName = logConfigurationDescribe.getName().replaceAll('__c','');
        String logGroupKeyPrefix  = logGroupDescribe.getKeyPrefix();
        logGroupObjectName = (logGroupObjectName.contains('__')) ? logGroupObjectName.substringAfter('__') : logGroupObjectName;
        logConfigurationLookupFieldName =   (logConfigurationLookupFieldName.contains('__'))  ? logConfigurationLookupFieldName.substringAfter('__') : logConfigurationLookupFieldName;

        String lkid = '000000000000000';
        if (!Test.isRunningTest()) {
            Api.Client client = new Api.Client();
            client.endpoint_x = podProtocolAndHost() + '/services/Soap/T/29.0';
            Api.QueryResult customObjects = client.query('SELECT Id FROM CustomObject WHERE DeveloperName = \'' + logGroupObjectName + '\'');
            Id logGroupObjectId = customObjects.records[0].Id;
            Api.QueryResult customFields = client.query('SELECT Id FROM CustomField WHERE DeveloperName = \'' + logConfigurationLookupFieldName + '\' AND TableEnumOrId = \'' + logGroupObjectId + '\'');
            lkid = customFields.records[0].Id.left(15);
        }
        
        return new PageReference( '/' + logGroupKeyPrefix + '?rlid=' + lkid + '&id=' + logConfigurationId );
    }
}