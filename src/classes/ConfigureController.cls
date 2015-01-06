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
    
    /**
     * eg "https://pod.salesforce.com"
     */
    public String getPodProtocolAndHost() {
        return RemoteSiteSettingController.protocolAndHost;
    }
    
    /**
     * If we don't have an OAuthSetting__c with an AccessToken__c this
     * quickly sends us through the dance to get that set up correctly.
     */
    public PageReference initOAuth() {
        PageReference retURL = ApexPages.currentPage();
        return OAuthController.doDanceIfNeeded(retURL);
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
        this.HasRemoteSiteSetting = RemoteSiteSettingController.isRssPresent;
    }
    
    /**
     * Is EVERYTHING installed correctly?
     */
    public Boolean getIsOk() {
        return this.getHasHeartbeat();
    }
    
    public PageReference doGetStarted() {
        return new PageReference(this.getAppMenuItem().StartUrl);
    }
    
}