public with sharing class ConfigureController {
    
    /**
     * Sometimes the CronJobDetail takes a while to populate.
     * We are happy enough knowing just the CronJob Id exists
     * in order to display that the Scheduled Job is alright.
     * This gives immediate feedback when you press
     * "Click here to schedule the job to fix this"
     */
    private Id CronDetailId;
    
    private AppMenuItem AppMenuItem;
    private AppMenuItem getAppMenuItem() {
        if (this.AppMenuItem == null) this.AppMenuItem = [SELECT Id, StartUrl FROM AppMenuItem WHERE Name = 'EnterpriseServiceBus'];
        return this.AppMenuItem;
    }
    
    private List<CronJobDetail> CronJobDetails;
    private List<CronJobDetail> getCronJobDetails() {
        if (this.CronJobDetails == null) this.CronJobDetails = [SELECT Id FROM CronJobDetail WHERE Name = 'Heartbeat (do not delete)'];
        return this.CronJobDetails;
    }
    
    private List<Process__c> Processes;
    private List<Process__c> getProcesses() {
        if (this.Processes == null) this.Processes = [SELECT Id FROM Process__c WHERE FullyQualifiedClassName__c = :Terminate.class.getName()];
        return this.Processes;
    }
    
    private String HomeContent;
    private String getHomeContent() {
        if (this.HomeContent == null) this.HomeContent = Test.isRunningTest() ? '' : new PageReference('/home/home.jsp').getContent().toString();
        return this.HomeContent;
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
    private String PodProtocolAndHost;
    public String getPodProtocolAndHost() {
        if (this.PodProtocolAndHost == null) {
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
            this.PodProtocolAndHost = rest.getProtocol() + '://' + rest.getHost();
        }
        return this.PodProtocolAndHost;
    }
    
    public PageReference doRedirect() {
        Map<String,String> params = ApexPages.currentPage().getParameters();
        
        if (params.containsKey('retURL') && getIsOk()) {
            //back where you came from
            String url = params.get('retURL');
            return new PageReference(url);
        }
        
        //on with setup
        return null;
    }
    
    /**
     * App visibility can come from Profile associations or from Permission Sets.
     * Unfortunately, Permission Sets only work in a dev org, not for an install.
     * For installed users, we can detect the app's visibility from the app menu.
     */
    public Boolean getHasApp() {
        //get the application id and scrape the home page
        String appId = String.valueOf(this.getAppMenuItem().Id).left(15);
        
        if (this.getHomeContent().contains(appId)) {
            //the app is visible
            return true;
        }
        
        if (this.getHomeContent().contains('Enterprise Service Bus')) {
            //the app is currently selected
            return true;
        }
        
        //needs to be set up!
        return false;
    }
    
    public PageReference doSetupApp() {
        //scaffold edit url and append url parameter for your profile
        PageReference pr = new ApexPages.StandardController(this.getAppMenuItem()).edit();
        pr.getParameters().put('retURL', ApexPages.currentPage().getUrl());
        pr.getParameters().put('selected_in_profile', String.valueOf(UserInfo.getProfileId()).left(15));
        return pr;
    }
    
    /**
     * The Heartbeat scheduled job is required for the 'Schedule' process to run.
     * If a System Administrator inadvertently deletes it, it can be recreated here.
     */
    public Boolean getHasHeartbeat() {
        if (this.CronDetailId != null) return true;
        return this.getCronJobDetails().size() == 1;
    }
    
    public void doSetupHeartbeat() {
        //schedule the job
        this.CronDetailId = PostInstallHandler.installSchedule();
    }
    
     /**
     * Detect if Remote Site Setting is deployed
     */
    public Boolean HasRemoteSiteSetting {get; set;}
    public void detectRemoteSiteSetting() {
        HttpRequest request = new HttpRequest();
        request.setEndpoint(this.getPodProtocolAndHost());
        request.setMethod('GET');
        
        try {
            new Http().send(request);
            this.HasRemoteSiteSetting = true;
        } catch (CalloutException e) {
            //remote site setting is missing
            this.HasRemoteSiteSetting = false;
        }
    }
    
    /**
     * Is EVERYTHING installed correctly?
     */
    public Boolean getIsOk() {
        return this.getHasApp() && this.getHasHeartbeat();
    }
    
    public PageReference doGetStarted() {
        return new PageReference(this.getAppMenuItem().StartUrl);
    }
    
}