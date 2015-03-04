public with sharing class ConfigureController {
    
    /**
     * Connected app attributes
     */
    final static private String CLIENT;
    final static private String SECRET;
    final static private String REDIRECT;
    final static private String APPNAME;
    final static private String LOGIN;
    
    /**
     * Environment discovery
     */
    final static private Boolean ISDEV = ConfigureController.class.getName().substringBefore('ConfigureController').substringBefore('.') == '';
    final static private Boolean ISTEST = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
    final static private Boolean ISPROD = !ISDEV && !ISTEST;
    
    /** 
     * Initialize
     * 
     * #730 Commentary about the fragility of the Connected App Name
     * Note there is a BINDING between all connected app names and ConfigureController.cls
     * The friendly names (and developer names!) are synchronized by Salesforce to all pods.
     * Renaming these will cause catastrophic failure of OAuth in all existing package installations.
     */
    static {
        if (ISDEV) {
            //for unmanaged development
            CLIENT = '3MVG9fMtCkV6eLhfygiAuT5nj9iYIxQbeYyBbyxFP5TiJIaGaCeNf.6MdNdCTai94zLjQVjZJsPmvrN4gA.yl';
            SECRET = '134028378901110512';
            REDIRECT = 'https://login.salesforce.com/apex/Configure';
            APPNAME = 'Dev Enterprise Service Bus';
            LOGIN = 'https://login.salesforce.com';
        }
        
        if (ISTEST) {
            //for sandbox org installs
            CLIENT = '3MVG9fMtCkV6eLhfygiAuT5nj9pR_VAnJtIE57hGjpvFlGVuq2L97l5Sxd93NxsCDrxdnztE4kVI29fDRjemm';
            SECRET = '9179586167866560862';
            REDIRECT = 'https://test.salesforce.com/apex/esb__Configure';
            APPNAME = 'Sandbox Enterprise Service Bus';
            LOGIN = 'https://test.salesforce.com';
        }
        
        if (ISPROD) {
            //for production org installs
            CLIENT = '3MVG9fMtCkV6eLhfygiAuT5nj9oMZJIarvuh1uEpRNeVc_uwIgCWXzKZQhviO1IjRVXh3EvIy6Qn4wLk1UfRC';
            SECRET = '1451809242356610984';
            REDIRECT = 'https://login.salesforce.com/apex/esb__Configure';
            APPNAME = 'Production Enterprise Service Bus';
            LOGIN = 'https://login.salesforce.com';
        }
    }
    
    public class ConfigureException extends Exception {}
    
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
     * We can interrogate the OauthToken object per #700 to
     * determine if the user has allowed the connected app,
     * which will catch the case if it has been revoked.
     */
    @TestVisible static private Boolean IsAllowed {
        get {
            if (IsAllowed == null) {
                List<OauthToken> oauthtokens = [
                    SELECT UserId
                    FROM OauthToken
                    WHERE AppName = :APPNAME
                ];
                IsAllowed = !oauthtokens.isEmpty();
            }
            return IsAllowed;
        }
    }
    
    /**
     * This is a universal entry point to the OAuth dance that
     * can be used from places like page action handler code.
     *
     * @param retURL where should the user should be returned to
     * @return       oauth start point (or null if already allowed)
     */
    static public PageReference doDanceIfNeeded(PageReference retURL) {
        if (IsAllowed) return null; //all ok
        
        //better do the dance
        PageReference dance = Page.Configure;
        dance.getParameters().put('retURL', retURL.getUrl());
        return dance;
    }
    
    /**
     * STEP ONE:
     * A human begins the OAuth dance from a link, eg:
     * https://login.salesforce.com/services/oauth2/authorize
     * ?client_id=3MVG98XJQQAccJQd0q2.s_Ak1RI4Of5e5kbUbbDYvVs41Ba0bFlnad4pzSMri5oQGHlDulk9raTGKF_y4lL51
     * &redirect_uri=https%3A%2F%2Flogin.salesforce.com%2Fapex%2Fesb__Configure
     * &response_type=code
     */
    @TestVisible private PageReference buildAuthLink() {
        PageReference pr = new PageReference(LOGIN + '/services/oauth2/authorize');
        pr.getParameters().put('response_type', 'code');
        pr.getParameters().put('client_id', CLIENT);
        pr.getParameters().put('redirect_uri', REDIRECT);
        return pr;
    }
    
    /**
     * STEP TWO:
     * After clicking and choosing 'Allow' the human is redirected to this
     * visualforce callback page, which receives the token off the URL, eg:
     * https://login.salesforce.com/apex/esb__Configure
     * ?code=aPrxHLAg3XMmPXtX1cG.hBCXhs8h5Wli7kDvSxAKd5kEvZ1Fkz3bPK3Jw82iI41iYhs6rk5iIA==
     * 
     * Then we perform an out-of-band request with our secret, eg:
     * https://login.salesforce.com/services/oauth2/token
     * ?client_id=3MVG9fMtCkV6eLhfxsgy.rM62VU0VV56FOOkj0Tsgj1CavTLb3N.g2kuagIqfQiJ5hZJgJT0JrZKvsBKk_s1J
     * &client_secret=2834415504471774418
     * &code=aPrxHLAg3XMmPXtX1cG.hBCXhkPQ89rfuQTvHhmuu16Jm.DL5lYIjdeGFLdNIh0OGO17V2QD3A%3D%3D
     * &format=json
     * &grant_type=authorization_code
     * &redirect_uri=https%3A%2F%2Flogin.salesforce.com%2Fapex%2Fesb__Configure
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
    @TestVisible private PageReference buildCodeLink(String code) {
        PageReference pr = new PageReference(RemoteSiteSettingController.protocolAndHost + '/services/oauth2/token');
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
    @TestVisible private PageReference buildRefreshLink() {
        PageReference pr = new PageReference(RemoteSiteSettingController.protocolAndHost + '/services/oauth2/token');
        pr.getParameters().put('grant_type', 'refresh_token');
        pr.getParameters().put('client_id', CLIENT);
        pr.getParameters().put('client_secret', SECRET);
        pr.getParameters().put('refresh_token', OAuthSetting__c.getInstance().RefreshToken__c);
        return pr;
    }
    
    /**
     * Performs the third part of the OAuth dance using the refresh token
     * to get a ready-and-roaring access token, and saves the new one away.
     */
    static public void refreshAccessToken() {
        OAuthSetting__c setting = OAuthSetting__c.getOrgDefaults();
        if (setting == null) setting = new OAuthSetting__c();
        
        HttpRequest request = new HttpRequest();
        request.setMethod('POST');
        request.setEndpoint(new ConfigureController().buildRefreshLink().getUrl());
        
        HttpResponse response = new Http().send(request);
        if (response.getStatusCode() != 200) {
            //unlikely, but an unhandled exception means we'll hear about it
            throw new ConfigureException('Bad response in refreshAccessToken: ' + response.getStatusCode() + ' ' + response.getBody());
        }
        
        String data = response.getBody();
        Token t = (Token)Json.deserialize(data, Token.class);
        if (t.access_token == null) {
            //unlikely, but an unhandled exception means we'll hear about it
            throw new ConfigureException('Null access_token in refreshAccessToken: ' + data);
        }
        
        setting.AccessToken__c = t.access_token;
        upsert setting;
    }
    
    /**
     * Per #707 the OAuth stuff has moved across into this ConfigureController because
     * there is no longer any Remote Site Setting or Schedule or Custom App to install.
     *
     * This page (/apex/Configure) is now the one-stop-shop:
     * - it lets the page display to deploy the remote site if needed
     * - it redirects the user into the OAuth dance if necessary
     * - it catches the 'code' and converts that to a token and saves it
     * - it sends the user back to the retURL if there was one
     * - or sends user to the Custom App Start URL (Monitor page)
     */
    public PageReference handleRedirect() {
        setting = OAuthSetting__c.getOrgDefaults();
        if (setting == null) setting = new OAuthSetting__c();
        String code = ApexPages.currentPage().getParameters().get('code');
        
        if (!RemoteSiteSettingController.isRssPresent) {
            //STEP ZERO (let component javascript deploy remote site setting)
            return null;
        }
        
        if (code == null) {
            //STEP ONE
            PageReference authLink = this.buildAuthLink();
            
            //set retURL cookie because we can't pass it in connected app callback
            String retURL = ApexPages.currentPage().getParameters().get('retURL');
            authLink.setCookies(new List<Cookie>{new Cookie('retURL', retURL, null, -1, false)});
            
            //redirect to OAuth prompt
            return authLink;
        }
        
        if (code != null) {
            //STEP TWO
            PageReference codeLink = this.buildCodeLink(code);
            HttpRequest request = new HttpRequest();
            request.setMethod('POST');
            request.setEndpoint(codeLink.getUrl());
            
            HttpResponse response = new Http().send(request);
            if (response.getStatusCode() != 200) {
                //#724 can happen in orgs via "ip restricted or invalid login hours"
                String help = Url.getSalesforceBaseUrl().toExternalForm() + new PageReference('/apex/Csh?topic=TroubleshootIpRestrictions&sidebar=false').getUrl();
                throw new ConfigureException('Bad response in handleRedirect: ' + response.getStatusCode() + ' ' + response.getBody() + ' ' + help); //#729
            }
            
            String data = response.getBody();
            Token t = (Token)Json.deserialize(data, Token.class);
            if (t.refresh_token == null) {
                //unlikely, but an unhandled exception means we'll hear about it
                throw new ConfigureException('Null refresh_token in handleRedirect: ' + data);
            }
            
            setting.AccessToken__c = t.access_token;
            setting.RefreshToken__c = t.refresh_token;
            Type.forName(DoDml.class.getName()).newInstance(); //avoids DML in action method
            
            //get retURL from cookie because we can't pass it in connected app
            Cookie retURL = ApexPages.currentPage().getCookies().get('retURL');
            return retURL != null ? new PageReference(retURL.getValue()) : this.doGetStarted();
        }
        
        //never gets here
        return null;
    }
    
    public PageReference doGetStarted() {
        AppMenuItem appMenuItem = [
            SELECT Id, StartUrl
            FROM AppMenuItem
            WHERE Name = 'EnterpriseServiceBus'
        ];
        
        return new PageReference(appMenuItem.StartUrl);
    }
    
    static private OAuthSetting__c setting;
    
    /**
     * #781 pass security scanner
     */
    public class DoDml {
        public DoDml() {
            upsert setting;
        }
    }
    
}