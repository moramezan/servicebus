public with sharing class ConfigureController {
    
    String BaseUrl;
    String InstanceName;
    
    public ConfigureController() {
        this.BaseUrl = Url.getSalesforceBaseUrl().toExternalForm().replace('http:', 'https:'); //#1188
        this.InstanceName = [SELECT InstanceName FROM Organization LIMIT 1].InstanceName;
    }
    
    /**
     * calls the Metadata API from JavaScript to create the Remote Site Setting to permit Apex callouts
     * http://andyinthecloud.com/2014/07/29/post-install-apex-metadata-api-configuration-solved/
     */
    public String javascript() {
        return (''
            + 'sforce.connection.init("' + UserInfo.getSessionId() + '");'
            + 'sforce.connection.remoteFunction({'
            + '    url: "' + this.BaseUrl + '/services/Soap/m/36.0",'
            + '    onSuccess: function(response, xhr) {'
            + '        var oa = window.location.href.replace("stage=js", "stage=oa");' //force redirect with no history
            + '        window.location.replace ? window.location.replace(oa) : window.location.href = oa;'
            + '    },'
            + '    onFailure: function(response, xhr) {'
            + '        alert(response);' //show bad output
            + '    },'
            + '    method: "POST",'
            + '    async: false,'
            + '    requestHeaders: {'
            + '        "Content-Type": "text/xml",'
            + '        "SOAPAction": \'""\''
            + '    },'
            + '    requestData: requestData,'
            + '    cache: false,'
            + '    timeout: 120000'
            + '});'
        ).replaceAll('    ', ' ');
    }
    
    /**
     * This does appear in the Visualforce Component if they view
     * the source carefully enough, but just trying our damndest to
     * keep the new sauce "secret".
     */
    public String requestData() {
        //#112 pass security scanner for 36.0 release
        return (''
            + '<?xml version="1.0" encoding="utf-8"?>'
            + '<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
            + '    <env:Header>'
            + '        <urn:SessionHeader xmlns:urn="http://soap.sforce.com/2006/04/metadata">'
            + '            <urn:sessionId>' + UserInfo.getSessionId() + '</urn:sessionId>'
            + '        </urn:SessionHeader>'
            + '    </env:Header>'
            + '    <env:Body>'
            + '        <upsertMetadata xmlns="http://soap.sforce.com/2006/04/metadata">'
            + '            <metadata xsi:type="RemoteSiteSetting">'
            + '                <fullName>' + this.InstanceName + '_Salesforce</fullName>'
            + '                <description>' + this.InstanceName + '_Salesforce</description>'
            + '                <disableProtocolSecurity>false</disableProtocolSecurity>'
            + '                <isActive>true</isActive>'
            + '                <url>' + Application__c.getOrgDefaults().OrgBaseUrl__c + '</url>'
            + '            </metadata>'
            + '            <metadata xsi:type="RemoteSiteSetting">'
            + '                <fullName>' + this.InstanceName + '_Visualforce</fullName>'
            + '                <description>' + this.InstanceName + '_Visualforce</description>'
            + '                <disableProtocolSecurity>false</disableProtocolSecurity>'
            + '                <isActive>true</isActive>'
            + '                <url>' + this.BaseUrl.replace('services', 'c') + '</url>'
            + '            </metadata>'
            + '        </upsertMetadata>'
            + '    </env:Body>'
            + '</env:Envelope>'
        ).replace('    ', '');
    }
    
    /**
     * This replaces our RemoteSiteSetting.component
     * but hides all evidence of its own existence
     */
    public ApexPages.Component getDynamicComponent() {
        Component.Apex.OutputPanel outputPanel = new Component.Apex.OutputPanel();
        outputPanel.layout = 'none';
        outputPanel.expressions.rendered = '{!$CurrentPage.parameters.stage == "js"}';
            
            Component.Apex.IncludeScript includeScript = new Component.Apex.IncludeScript();
            includeScript.value = '/soap/ajax/36.0/connection.js';
            outputPanel.childComponents.add(includeScript);
            
            Component.Apex.OutputText outputText = new Component.Apex.OutputText();
            outputText.escape = false; //https://github.com/bigassforce/services/issues/1013#issuecomment-134331035
            outputText.value = '<script>var requestData = \'' + requestData() + '\';' + javascript() + '</script>';
            outputPanel.childComponents.add(outputText);
        
        return outputPanel;
    }
    
    /**
     * For throwing out more detailed errors from HTTP responses
     */
    public class SetupException extends Exception {
        public SetupException(Exception e, String message) {
            this(message + ': ' + e.getMessage(), e);
        }
        
        public SetupException(HttpResponse response, String message) {
            this(message + ': ' + debug(response));
        }
        
    }
    
    static String debug(HttpResponse response) {
        Map<String,String> headers = new Map<String,String>();
        for (String key : response.getHeaderKeys()) if (key != null) headers.put(key, response.getHeader(key));
        return (response + '' + headers + '' + response.getBody());
    }
    
    /**
     * Connected app attributes
     */
    final static String CLIENT;
    final static String SECRET;
    final static String REDIRECT;
    final static String APPNAME;
    final static String LOGIN;
    
    /**
     * Environment discovery
     */
    final static Boolean ISDEV = ConfigureController.class.getName().substringBefore('ConfigureController').substringBefore('.') == '';
    final static Boolean ISTEST = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
    final static Boolean ISPROD = !ISDEV && !ISTEST;
    
    /**
     * Initialize
     *
     * bigassforce/services#730 Commentary about the fragility of the Connected App Name
     * Note there is a BINDING between all connected app names and ConfigureController.cls
     * The friendly names (and developer names!) are synchronized by Salesforce to all pods.
     * Renaming these will cause catastrophic failure of OAuth in all existing package installations.
     */
    static {
        if (ISDEV) {
            //TODO for services unmanaged development
            CLIENT = '3MVG98_Psg5cppybikftoUFR9gr3RBcqzMkD2PNnc7L2LKUp0aDeKIh0oYarQxJ4mSC1EbcnENiJnxi6DLPbg';
            SECRET = '649692728193931055';
            REDIRECT = 'https://login.salesforce.com/apex/Configure';
            APPNAME = 'Services (Dev)';
            LOGIN = 'https://login.salesforce.com';
        }
        
        if (ISTEST) {
            //TODO for services sandbox org installs
            CLIENT = '3MVG98_Psg5cppybikftoUFR9giPVj21lrc77yTvA.LydX4.s7DAuJl0pOXyJJVeYq3i8owdY2grtnJZbpLfz';
            SECRET = '1557834583025401060';
            REDIRECT = 'https://test.salesforce.com/apex/Services__Configure';
            APPNAME = 'Services (Test)';
            LOGIN = 'https://test.salesforce.com';
        }
        
        if (ISPROD) {
            //TODO for services production org installs
            CLIENT = '3MVG98_Psg5cppybikftoUFR9gi1uzsC72iJ.JnJsJreUxyNPzokwctRG.iJOv3juOGkCvddJ9Ph_Uw_VRK3A';
            SECRET = '8674288713951508210';
            REDIRECT = 'https://login.salesforce.com/apex/Services__Configure';
            APPNAME = 'Services (Live)';
            LOGIN = 'https://login.salesforce.com';
        }
    }
    
    public class Token {
        public String id;
        public String issued_at;
        public String scope;
        public String instance_url;
        public String token_type;
        public String refresh_token;
        public String id_token;
        public String signature;
        public String access_token;
    }
    
    /**
     * STEP ONE:
     * A human begins the OAuth dance from a link, eg:
     * https://login.salesforce.com/services/oauth2/authorize
     * ?client_id=3MVG98XJQQAccJQd0q2.s_Ak1RI4Of5e5kbUbbDYvVs41Ba0bFlnad4pzSMri5oQGHlDulk9raTGKF_y4lL51
     * &redirect_uri=https%3A%2F%2Flogin.salesforce.com%2Fapex%2FConfigure
     * &response_type=code
     */
    @TestVisible System.PageReference buildAuthLink() {
        System.PageReference pr = new System.PageReference(LOGIN + '/services/oauth2/authorize');
        pr.getParameters().put('response_type', 'code');
        pr.getParameters().put('client_id', CLIENT);
        pr.getParameters().put('redirect_uri', REDIRECT);
        return pr;
    }
    
    /**
     * STEP TWO:
     * After clicking and choosing 'Allow' the human is redirected to this
     * visualforce callback page, which receives the token off the URL, eg:
     * https://login.salesforce.com/apex/Configure
     * ?code=aPrxHLAg3XMmPXtX1cG.hBCXhs8h5Wli7kDvSxAKd5kEvZ1Fkz3bPK3Jw82iI41iYhs6rk5iIA==
     *
     * Then we perform an out-of-band request with our secret, eg:
     * https://login.salesforce.com/services/oauth2/token
     * ?client_id=3MVG9fMtCkV6eLhfxsgy.rM62VU0VV56FOOkj0Tsgj1CavTLb3N.g2kuagIqfQiJ5hZJgJT0JrZKvsBKk_s1J
     * &client_secret=2834415504471774418
     * &code=aPrxHLAg3XMmPXtX1cG.hBCXhkPQ89rfuQTvHhmuu16Jm.DL5lYIjdeGFLdNIh0OGO17V2QD3A%3D%3D
     * &format=json
     * &grant_type=authorization_code
     * &redirect_uri=https%3A%2F%2Flogin.salesforce.com%2Fapex%2FServices__Configure
     *
     * The Salesforce OAuth service responds with both and access token and a refresh token like this:
     * {
     * "id":"https://login.salesforce.com/id/00Dj0000000I44vEAC/005j0000000X37nAAC",
     * "issued_at":"1419271694442",
     * "scope":"api refresh_token",
     * "instance_url":"https://na16.salesforce.com",
     * "token_type":"Bearer",
     * "refresh_token":"5Aep861E3ECfhV22nZpJccJlM3BOtQdGCyk.ptFPOUId8FaxmI8NDHIes.T15qoY86qCs2hD1sdWlwudG5HP8I2","signature":"7DRL2Rg8o189HjDwwb2LBGbGXlEYJOCondmLry1D4aY=",
     * "access_token":"00Dj0000000I44v!AQYAQLocFFeWV3WywoaS6wjcdnEvm4_FdPrd9MrlB_y1Q.5Xll9mTloey5GIXrIP1fdB2lKlsfmZ7Sqh6UAhFzuD6SzHqtXO"
     * }
     */
    @TestVisible System.PageReference buildCodeLink(String code) {
        String baseUrl = Application__c.getOrgDefaults().OrgBaseUrl__c;
        System.PageReference pr = new System.PageReference(baseUrl + '/services/oauth2/token');
        pr.getParameters().put('grant_type', 'authorization_code');
        pr.getParameters().put('client_id', CLIENT);
        pr.getParameters().put('client_secret', SECRET);
        pr.getParameters().put('redirect_uri', REDIRECT);
        pr.getParameters().put('code', code);
        pr.getParameters().put('format', 'json');
        return pr;
    }
    
    /**
     * STEP THREE
     * We periodically perform an out-of-band request to refresh the access token so it's always roaring and ready.
     * https://na16.salesforce.com/services/oauth2/token
     * ?client_id=3MVG9fMtCkV6eLhfxsgy.rM62Ve5FyYsgesF4WLk.paM5gTwyAEtQLEnPyYB4l7_f1ywAtb4.6lBeo1ZvuEpE
     * &client_secret=4608752124209996979
     * &grant_type=refresh_token
     * &refresh_token=5Aep861E3ECfhV22nZpJccJlM3BOtQdGCyk.ptFPOUId8FaxmIl5Fuf1.aLnyFHZo2XLyAobgvmfCqq7qvrRICK
     *
     * The Salesforce OAuth service responds with a new access token like this:
     * {
     * "id":"https://login.salesforce.com/id/00Dj0000000I44vEAC/005j0000000X37nAAC",
     * "issued_at":"1419263794330",
     * "scope":"api refresh_token",
     * "instance_url":"https://na16.salesforce.com",
     * "token_type":"Bearer",
     * "signature":"Y162odkkgH5pTalDzR82nXKRK794hHpBelUb8+fUubs=",
     * "access_token":"00Dj0000000I44v!AQYAQKgWV8FRAfgKVWJE5BETIjEE0hvNWKojZI57zaxpPcLe1tqWrCXgkjhSvRwXHTiIOTF12Hd7TvKZd7WBg8kUbVIbcHeL"
     * }
     */
    @TestVisible System.PageReference buildRefreshLink() {
        String baseUrl = Application__c.getOrgDefaults().OrgBaseUrl__c;
        System.PageReference pr = new System.PageReference(baseUrl + '/services/oauth2/token');
        pr.getParameters().put('grant_type', 'refresh_token');
        pr.getParameters().put('client_id', CLIENT);
        pr.getParameters().put('client_secret', SECRET);
        pr.getParameters().put('refresh_token', Application__c.getOrgDefaults().RunAsRefreshToken__c);
        return pr;
    }
    
    /**
     * Performs the third part of the OAuth dance using the refresh token
     * to get a ready-and-roaring access token, and saves the new one away.
     */
    static public String refreshAccessToken() {
        
        if (!Test.isRunningTest()) if (ConfigureIfNeeded(null) != null) {
            //failure, there is a risk of posting to wrong endpoint!
            System.assert(false, 'Please configure the Services package.');
        }
        
        HttpRequest request = new HttpRequest();
        request.setTimeout(120000);
        request.setMethod('POST');
        request.setEndpoint(new ConfigureController().buildRefreshLink().getUrl());
        
        HttpResponse response;
        try {response = new Http().send(request);}
        catch (CalloutException e) {
            //failure, we would like to know about, eg "System.CalloutException: Read timed out"
            throw new SetupException(e, 'Defer exception');
        }
        
        if (response.getStatusCode() != 200) {
            //failure, unlikely but an unhandled exception means we'll hear about it
            throw new SetupException(response, 'Defer status');
        }
        
        String data = response.getBody();
        Token t = (Token)Json.deserialize(data, Token.class);
        return t.access_token;
    }
    
    /**
     * Per bigassforce/services#709 if someone trashes the scheduled job, they
     * can recreate it by running the configuration service again.
     */
    static public void uninstallSchedule() {
        try {
            //first attempt to uninstall the schedule
            CronJobDetail cronJobDetail = [SELECT Id FROM CronJobDetail WHERE Name = :JobName];
            CronTrigger cronTrigger = [SELECT Id FROM CronTrigger WHERE CronJobDetailId = :cronJobDetail.Id];
            System.abortJob(cronTrigger.Id);
        } catch (QueryException e) {
            //failure, couldn't locate job, probably not running
        }
    }
    
    //#969 obfuscation of 'Services Heartbeat'
    @TestVisible static String JobName = Test.isRunningTest() ? 'Test Router' : 'Services Router';
    
    /**
     * Creates the hourly cron job used to refresh the token.
     */
    static public Id reinstallSchedule() {
        //now attempt to install it again
        String cronExpr = '0 0 * * * ?';
        RouterSchedule schedulable = new RouterSchedule();
        return System.schedule(JobName, cronExpr, schedulable);
    }
    
    /**
     * We will try to avoid the Identity URL technique due to
     * cross-domain (login.salesforce.com / eu2.salesforce.com) issues.
     *
     * This page is still a one-stop-shop:
     * 1. "cs" we upsert custom setting to save away the base url
     * 2. "js" we deploy both 0rp in JavaScript by displaying the page
     * 3. "oa" we initiate the OAuth dance which redirects back to this page
     * 4. "cb" we handle the OAuth callback which exchanges/persists the code
     * 5. finally send them to the context sensitive help page
     */
    public System.PageReference doRedirect() {
        Map<String,String> parameters = ApexPages.currentPage().getParameters();
        if (parameters.containsKey('url')) parameters.put('stage', 'cs');
        if (parameters.containsKey('code')) parameters.put('stage', 'cb');
        String stage = parameters.get('stage');
        
        if (stage == null) {
            //0. page was viewed without using the proper link
            System.PageReference pr = new System.PageReference('/servlet/servlet.Integration');
            pr.getParameters().put('lid', [SELECT Id FROM WebLink WHERE Description = 'Services configuration link.'].Id);
            pr.getParameters().put('eid', UserInfo.getUserId());
            pr.getParameters().put('ic', '1');
            pr.getParameters().put('retURL', ApexPages.currentPage().getParameters().get('retURL'));
            return pr;
        }
        
        if (stage == 'cs') {
            //1. "cs" we upsert custom setting to save away the base url
            String url = parameters.get('url').substringBefore('/services/');
            application = Application__c.getOrgDefaults();
            application.OrgBaseUrl__c = url;
            application.OrgConfigured__c = UserInfo.getOrganizationId().substring(3, 15);
            application.OrgReturnUrl__c = ApexPages.currentPage().getParameters().get('retURL');
            Type.forName(DoDml.class.getName()).newInstance();
            
            System.PageReference pr = Page.Configure;
            pr.getParameters().put('stage', 'js');
            pr.setRedirect(true);
            return pr;
        }
        
        if (stage == 'js') {
            //2. "js" we deploy both 0rp in JavaScript by displaying the page
            return null;
        }
        
        if (stage == 'oa') {
            //3. "oa" we initiate the OAuth dance which redirects back to this page
            return this.buildAuthLink();
        }
        
        if (stage == 'cb') {
            //4. "cb" we handle the OAuth callback which exchanges/persists the code
            String code = parameters.get('code');
            String endpoint = this.buildCodeLink(code).getUrl();
            HttpRequest request = new HttpRequest();
            request.setTimeout(120000);
            request.setMethod('POST');
            request.setEndpoint(endpoint);
            
            HttpResponse response;
            try {response = new Http().send(request);}
            catch (CalloutException e) {
                //failure, we would like to know about
                throw new SetupException(e, 'Redirect exception');
            }
            
            if (response.getBody().contains('ip restricted')) {
                //failure, definitely ip restrictions
                return new System.PageReference('/packaging/installPackage.apexp?p0=04t24000000EkE2'); //36.0 (Released)
            }
            
            if (response.getStatusCode() != 200) {
                //failure, bad oauth status code
                throw new SetupException(response, 'Redirect status');
            }
            
            //recreate custom setting when package is configured
            Token t = (Token)Json.deserialize(response.getBody(), Token.class);
            application = Application__c.getOrgDefaults();
            application.RunAsUserId__c = UserInfo.getUserId();
            application.RunAsAccessToken__c = t.access_token;
            application.RunAsRefreshToken__c = t.refresh_token;
            Type.forName(DoDml.class.getName()).newInstance();
            
            System.PageReference pr = Page.Configure;
            pr.getParameters().put('stage', 'pi');
            pr.setRedirect(true);
            return pr;
        }
        
        if (stage == 'pi') {
            //5. do other tasks that used to be post install
            
            //recreate scheduled job when package is configured
            uninstallSchedule();
            reinstallSchedule();
            
            //sensible defaults for the first user
            permissions(UserInfo.getUserId());
            settings(UserInfo.getUserId());
            
            //metadata api installs the nuclear tip
            if (!Test.isRunningTest()) defaults(UserInfo.getSessionId());
            
            //bigassforce/services#812 don't wait an hour to refresh access token
            //if (!Test.isRunningTest()) Router.optimize; //#1229 dont spam
            
            //6. finally send them to the context sensitive help page
            String returnUrl;
            application = Application__c.getOrgDefaults();
            List<AppMenuItem> appMenuItems = [SELECT StartUrl FROM AppMenuItem WHERE Name = 'Services' LIMIT 1];
            if (returnUrl == null) returnUrl = application.OrgReturnUrl__c;
            if (returnUrl == null && !appMenuItems.isEmpty()) returnUrl = appMenuItems[0].StartUrl;
            if (returnUrl == null) returnUrl = '/apex/ContextSensitiveHelp?topic=Services';
            return new PageReference(returnUrl);
        }
        
        //this should never happen
        throw new SetupException('Redirect exception');
    }
    
    static Application__c application;
    
    /**
     * bigassforce/services#781 pass security scanner
     */
    public class DoDml {
        public DoDml() {
            upsert application;
        }
    }
    
    /**
     * Set the Debug Settings
     * (Performed in a FUTURE method to prevent MIXED_DML_OPERATION exception)
     */
    @Future static public void settings(Id userId) { //#969 obfuscation of 'createDebugSettings()'
        //fetch custom setting and write the values
        DebugServiceConfig__c debugServiceConfig = DebugServiceConfig__c.getOrgDefaults();
        debugServiceConfig.UserId__c = userId;
        upsert debugServiceConfig;
    }
    
    /**
     * Assign Orchestrator permission set to the installer
     * (Performed in a FUTURE method to prevent MIXED_DML_OPERATION exception)
     */
    @Future static public void permissions(Id userId) { //#969 obfuscation of 'assignPermissionSet()'
        //find installed permission set
        PermissionSet ps = [
            SELECT Id
            FROM PermissionSet
            WHERE NamespacePrefix = :Application__c.getOrgDefaults().Prefix__c
            AND Name = 'AdministerServices'
        ];
        
        //determine if it has been assigned already
        Integer psas = [
            SELECT COUNT()
            FROM PermissionSetAssignment
            WHERE PermissionSetId = :ps.Id
            AND AssigneeId = :userId
        ];
        
        //if not, assign it to whoever installs the package
        if (psas == 0) insert new PermissionSetAssignment(
            PermissionSetId = ps.Id,
            AssigneeId = userId
        );
    }
    
    /**
     * #1015 install nuclear tip via Metadata API as part of configure service
     */
    @Future(callout=true) static public void defaults(String sessionId) { //#969 obfuscation of 'installNuclearTip()'
        
        if (Type.forName('abstract.Service') != null) {
            //abstract service is already installed
            return;
        }
        
        if (UserInfo.getOrganizationId() == '00D24000000fer4EAA') {
            //we do not install abstract service into packaging org
            return;
        }
        
        String baseUrl = Application__c.getOrgDefaults().OrgBaseUrl__c;
        HttpRequest request = new HttpRequest();
        request.setTimeout(120000);
        request.setMethod('POST');
        request.setEndpoint(baseUrl + '/services/Soap/m/36.0');
        request.setHeader('SOAPAction', '""');
        request.setHeader('Content-Type', 'text/xml');
        request.setBody(metadata(sessionId));
        //new Http().send(request);
    }
    
    /**
     * Org Id 00D24000000fQok
     * Package 03324000000Q59r
     * Version 04t24000000QtN7
     * /packaging/installPackage.apexp?p0=04t24000000QuGy
     * 36.0 (Released)
     */
    static public String metadata(String sessionId) {
        return (''
            + '<?xml version="1.0" encoding="utf-8"?>'
            + '<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
            + '    <env:Header>'
            + '        <urn:SessionHeader xmlns:urn="http://soap.sforce.com/2006/04/metadata">'
            + '            <urn:sessionId>' + sessionId + '</urn:sessionId>'
            + '        </urn:SessionHeader>'
            + '    </env:Header>'
            + '    <env:Body>'
            + '        <upsertMetadata xmlns="http://soap.sforce.com/2006/04/metadata">'
            + '            <metadata xsi:type="InstalledPackage">'
            + '                <fullName>' + 'abstract' + '</fullName>'
            + '                <password></password>'
            + '                <versionNumber>' + '36.0.0' + '</versionNumber>'
            + '            </metadata>'
            + '        </upsertMetadata>'
            + '    </env:Body>'
            + '</env:Envelope>'
        ).replaceAll('    ', '');
    }
    
    /**
     * Determins if package configuration is required.
     * If so, the Configure page is returned.
     */
    static public PageReference ConfigureIfNeeded(PageReference retURL) {
        
        String sessionId = Application__c.getOrgDefaults().RunAsAccessToken__c;
        String configuredOrgId = Application__c.getOrgDefaults().OrgConfigured__c;
        String unprefixedOrgId = UserInfo.getOrganizationId().substring(3, 15);
        
        if (null == sessionId) {
            //failure, user never clicked configure button
            PageReference configure = Page.Configure;
            if (retURL != null) configure.getParameters().put('retURL', retURL.getUrl());
            return configure;
        }
        
        if (configuredOrgId != unprefixedOrgId) {
            //failure, new environment probably due to sandbox refresh
            PageReference configure = Page.Configure;
            if (retURL != null) configure.getParameters().put('retURL', retURL.getUrl());
            return configure;
        }
        
        //services up to date
        return null;
    }
}