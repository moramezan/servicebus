public with sharing class OAuthController {
    
    final static private Boolean ISDEV = OAuthController.class.getName().substringBefore('OAuthController').substringBefore('.') == '';
    final static private String CLIENT = ISDEV ? '3MVG9fMtCkV6eLhfxsgy.rM62Ve5FyYsgesF4WLk.paM5gTwyAEtQLEnPyYB4l7_f1ywAtb4.6lBeo1ZvuEpE' : '3MVG9fMtCkV6eLhfxsgy.rM62VU0VV56FOOkj0Tsgj1CavTLb3N.g2kuagIqfQiJ5hZJgJT0JrZKvsBKk_s1J';
    final static private String SECRET = ISDEV ? '4608752124209996979' : '2834415504471774418';
    final static private String REDIRECT = ISDEV ? 'https://login.salesforce.com/apex/OAuth' : 'https://login.salesforce.com/apex/esb__OAuth';
    
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
     * &redirect_uri=https%3A%2F%2Flogin.salesforce.com%2Fapex%2Feda__OAuth
     * &response_type=code
     */
    public PageReference buildAuthLink() {
        PageReference pr = new PageReference('https://login.salesforce.com/services/oauth2/authorize');
        pr.getParameters().put('response_type', 'code');
        pr.getParameters().put('client_id', CLIENT);
        pr.getParameters().put('redirect_uri', REDIRECT);
        return pr;
    }
    
    /**
     * STEP TWO:
     * After clicking and choosing 'Allow' the human is redirected to this
     * visualforce callback page, which receives the token off the URL, eg:
     * https://login.salesforce.com/apex/esb__OAuth
     * ?code=aPrxHLAg3XMmPXtX1cG.hBCXhs8h5Wli7kDvSxAKd5kEvZ1Fkz3bPK3Jw82iI41iYhs6rk5iIA==
     * 
     * Then we perform an out-of-band request with our secret, eg:
     * https://login.salesforce.com/services/oauth2/token
     * ?client_id=3MVG9fMtCkV6eLhfxsgy.rM62VU0VV56FOOkj0Tsgj1CavTLb3N.g2kuagIqfQiJ5hZJgJT0JrZKvsBKk_s1J
     * &client_secret=2834415504471774418
     * &code=aPrxHLAg3XMmPXtX1cG.hBCXhkPQ89rfuQTvHhmuu16Jm.DL5lYIjdeGFLdNIh0OGO17V2QD3A%3D%3D
     * &format=json
     * &grant_type=authorization_code
     * &redirect_uri=https%3A%2F%2Flogin.salesforce.com%2Fapex%2Fesb__OAuth
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
    public PageReference buildCodeLink(String code) {
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
    public PageReference buildRefreshLink() {
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
        request.setEndpoint(new OAuthController().buildRefreshLink().getUrl());
        
        String data = new Http().send(request).getBody();
        Token t = (Token)Json.deserialize(data, Token.class);
        setting.AccessToken__c = t.access_token;
        upsert setting;
    }
    
    public PageReference handleRedirect() {
        OAuthSetting__c setting = OAuthSetting__c.getOrgDefaults();
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
            
            String data = new Http().send(request).getBody();
            Token t = (Token)Json.deserialize(data, Token.class);
            setting.AccessToken__c = t.access_token;
            setting.RefreshToken__c = t.refresh_token;
            upsert setting;
            
            //get retURL from cookie because we can't pass it in connected app
            Cookie retURL = ApexPages.currentPage().getCookies().get('retURL');
            return retURL != null ? new PageReference(retURL.getValue()) : Page.Configure;
        }
        
        //never gets here
        return null;
    }
}