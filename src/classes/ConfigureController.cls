public without sharing class ConfigureController {
    
    String endpoint = Url.getSalesforceBaseUrl().toExternalForm();
    
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
    static public String podProtocolAndHost() {
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
    
    @testVisible void attemptCallout(String endpoint) {
        System.HttpRequest request = new System.HttpRequest();
        request.setMethod('GET');
        request.setEndpoint(endpoint);
        new System.Http().send(request);
    }
    
    @testVisible System.PageReference buildSetupPage() {
        //prepare a link to our configuration/tutorial page which tests it
        System.PageReference configure = Page.Configure;
        configure.getParameters().put('endpoint', this.endpoint);
        
        //prepare a link to pre-populated remote site setting
        System.PageReference setup = new System.PageReference('/0rp/e');
        setup.getParameters().putAll(new Map<String,String>{
            'saveURL' => configure.getUrl(), //redirects to our configuration/tutorial after save
            'SiteName' => 'EDA_' + this.endpoint.replaceAll('[^A-Za-z0-9]+', '_').left(30),
            'EndpointUrl' => this.endpoint,
            'ProtocolMismatch' => '1',
            'DescriptionField' => 'This Remote Site Setting must be saved.'
        });
        
        return setup;
    }
    
    public System.PageReference doRedirect() {
        //resolve endpoint
        this.endpoint = podProtocolAndHost();
        
        //edge case: if the page was viewed directly (curious customer), just display the page
        if (null == endpoint) return null;
        
        try {
            //first we will attempt a callout to see if the remote site setting is set up correctly
            this.attemptCallout(this.endpoint);
        } catch (System.CalloutException e) {
            //if the callout failed, we need the admin to configure the remote site setting!
            return this.buildSetupPage();
        }
        
        //if the callout succeeded, show green message and display the page
        ApexPages.addMessage(new ApexPages.Message(
            ApexPages.Severity.CONFIRM,
            'Your Remote Site Settings appear to be configured correctly.'
        ));
        
        return null;
    }
}