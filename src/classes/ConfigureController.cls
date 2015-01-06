public with sharing class ConfigureController {
    
    private AppMenuItem AppMenuItem;
    private AppMenuItem getAppMenuItem() {
        if (this.AppMenuItem == null) this.AppMenuItem = [SELECT Id, StartUrl FROM AppMenuItem WHERE Name = 'EnterpriseServiceBus'];
        return this.AppMenuItem;
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
     * Detect if Remote Site Setting is deployed
     */
    public Boolean HasRemoteSiteSetting {get; set;}
    public void detectRemoteSiteSetting() {
        this.HasRemoteSiteSetting = RemoteSiteSettingController.isRssPresent;
    }
    
    public PageReference doGetStarted() {
        return new PageReference(this.getAppMenuItem().StartUrl);
    }
    
}